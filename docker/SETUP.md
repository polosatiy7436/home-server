# Homelab Setup Runbook

Complete recreation guide for this server. Written for a human or an AI agent
rebuilding the setup from scratch on a fresh Arch Linux host. Last verified: 2026-07-15.

## Host overview

- **OS**: Arch Linux (rolling), user `pi` (uid/gid 1000), home `/home/pi`
- **Storage**: 2× Crucial P3 1TB NVMe in RAID (`/dev/md127`, mounted `/`);
  Samsung T7 1TB USB SSD mounted at `/home/pi/media` (media only, re-downloadable)
- **Timezone**: Asia/Tbilisi
- `pi` is in the `docker` group (rootless docker CLI, root-equivalent)
- **No passwordless sudo** — everything below works without root except where noted
- **Security model**: nothing is port-forwarded to the internet; the LAN is
  trusted and the only remote path in is Tailscale (authenticated devices,
  exit node + subnet route). All "weak auth" choices below assume this holds.

## Directory layout

| Path | Purpose | Version control |
|---|---|---|
| `/home/pi/docker` | Docker Compose stack (this repo) | git (local only) |
| `/home/pi/scripts` | Cron scripts + shared libs | git (local only) |
| `/home/pi/apps/<name>` | Per-service persistent data (bind mounts) | restic backup |
| `/home/pi/media` | Media library (tv/movies/music/podcasts) | not backed up |
| `/home/pi/Storage/backups` | DB dumps, restic repo, crontab backup | restic repo itself |
| `/home/pi/bin` | User-installed binaries (restic) | no |

## Docker stack

Root `docker-compose.yml` is only an `include:` list; each service group lives in
`compose/<group>.yml` (dashboard, media, monitoring, photos, mealie, cloud, proxy,
wiki, vaultwarden, dns, tools). Run everything from `/home/pi/docker`:

```bash
docker compose up -d          # whole stack
docker compose up -d <svc>    # one service
```

### Secrets model

- Plaintext sources: `secrets/sources/<service>.env` (gitignored, chmod 600)
- `secrets/secrets.sh` regenerates one flat file per key in `secrets/`
  (referenced by compose `secrets:` blocks). **Parsing splits on the FIRST `=`
  only** — values may contain `=` (base64 keys).
- Containers consume them via `*_FILE` / linuxserver `FILE__*` env vars.
  No plaintext credentials belong in compose files.
- Special cases:
  - **pihole v6**: password NOT env-driven; set once via
    `docker exec pihole pihole setpassword '<pw>'` (hash persists in
    `/home/pi/apps/pihole/pihole.toml`); reference copy in `sources/pihole.env`
  - **vaultwarden**: `ADMIN_TOKEN_FILE` (plain `ADMIN_TOKEN=<path>` would make
    the path string itself the token)
  - **immich env** (paths, version) lives in `env/immich.env`, wired via the
    include-level `env_file` in the root compose file

### Recreate from scratch

```bash
cd /home/pi/docker
# 1. restore secrets/sources/*.env + env/*.env from the restic backup (gitignored!)
bash secrets.sh
docker compose up -d
```

## Backups (restic)

- Binary: `/home/pi/bin/restic` — **carries `cap_dac_read_search=+ep`** so it can
  read root/www-data-owned files (letsencrypt, config.php, grafana.db).
  **Re-apply after every binary update** (capability dies with the old inode):
  `sudo setcap cap_dac_read_search=+ep /home/pi/bin/restic` (or via a privileged
  container if no sudo — mount host setcap + libcap into any running image).
- Repo: `/home/pi/Storage/backups/restic-repo`, encrypted. Password in
  `/home/pi/scripts/backup/.restic.env` (gitignored) — **the user keeps an
  off-machine copy; without it the repo is unrecoverable.**
- Nightly 02:00 (`scripts/backup/restic_backup.sh`):
  1. `dump_databases.sh` — pg_dumpall/mariadb-dump for immich, nextcloud, mealie,
     bookstack, npm (credentials read inside each container; mariadb roots come
     from `$MYSQL_ROOT_PASSWORD_FILE` — keep in sync if compose env wiring
     changes!) + consistent vaultwarden sqlite copy via the online-backup API.
     A dump failure still lets the snapshot proceed but propagates a non-zero
     exit → Kuma push monitor goes down.
  2. restic snapshot of `/home/pi/apps`, `/home/pi/docker`, `/home/pi/scripts`,
     dumps + crontab backup. Excludes: `nextcloud/data` (already synced to the
     user's devices), raw DB data dirs, caches/thumbs
  3. `forget --prune`: 7 daily / 4 weekly / 6 monthly
  4. chmod pass so the nextcloud container can read the repo
  - flock-guarded against concurrent runs; `restic unlock` clears stale locks
- Monthly on the 1st: `restic_check.sh` (reads 5% of repo data)
- Off-site: Nextcloud external storage **"Backups"** (files_external mount id 1,
  local, readonly) points at the repo, mounted `ro` into the nextcloud container
  at `/mnt/restic-repo`. The user's devices sync that folder via Nextcloud clients
  — they ARE the off-site copies. (B2 was evaluated and abandoned; bucket deleted.)
- **Mount options are load-bearing** (stored in `oc_external_options`, mount 1):
  `readonly=1`, and `filesystem_check_changes=1` — without the latter Nextcloud
  never notices files restic writes directly to disk and clients silently stop
  receiving new snapshots. Set via:
  `occ files_external:option 1 filesystem_check_changes 1`
  (`files_external:list` does NOT display these — query the DB or trust occ.)
- Restore test: `restic -r /home/pi/Storage/backups/restic-repo snapshots`

## Scripts & notifications

`/home/pi/scripts` layout: `backup/`, `docker/`, `media/`, `system/`, `lib/`.

Every cron script follows one pattern:

```bash
source /home/pi/scripts/lib/notify.sh
my_task() { ...; }
run_with_notify my_task
```

`run_with_notify` pipes all output to Telegram (`send_to_telegram.py`, bot creds
in `scripts/.env`) and, if `scripts/.kuma.env` defines `KUMA_TOKEN_<function>`,
pushes up/down + exit code to the matching Uptime Kuma push monitor.

## Crontab (user pi)

```cron
0 0 * * * /home/pi/scripts/backup/backup_crontab.sh
0 7 1 * * /home/pi/scripts/docker/docker_cleanup.sh
0 3 * * * /home/pi/scripts/media/run_jellyfin_lyrics.sh
0 0 * * 1 /home/pi/scripts/media/cleanup_lyrics_log.sh
0 15 * * * /home/pi/scripts/backup/backup_vaultwarden.sh
0 6 * * 3 /home/pi/scripts/docker/docker_update_and_prune.sh >> /home/pi/docker_update.log 2>&1
0 2 * * * /home/pi/scripts/backup/restic_backup.sh
0 5 1 * * /home/pi/scripts/backup/restic_check.sh
```

## Monitoring & alerting

- **Uptime Kuma** :3001 (`louislam/uptime-kuma:2` — the docker-hub `latest` tag
  is permanently stuck on 1.x, never use it). Holds HTTP monitors, Docker
  container monitors (socket mounted ro), and push (dead-man's-switch) monitors
  for restic_backup / restic_check / backup_vaultwarden. Alerts via Telegram.
- **Grafana** :3000 + Prometheus + cadvisor + node-exporter + smartctl-exporter
  (all on the `internal` network). smartctl-exporter (privileged, :9633 internal)
  feeds SMART health/temps for all 3 disks into Prometheus (job `smartctl`);
  Grafana dashboard: import ID **20204**.
- **Nextcloud logging**: `log_rotate_size=100MB`, `loglevel=2` (was an unrotated
  1.1GB file once — don't regress this).

## Port map (host)

| Port | Service | | Port | Service |
|---|---|---|---|---|
| 53/67 | pihole DNS/DHCP | | 6875 | bookstack |
| 80/443/81 | nginx-proxy-manager | | 7878 | radarr |
| 82 | pihole web | | 8003 | cyberchef |
| 85/3012 | vaultwarden | | 8010 | *(free)* |
| 2283 | immich | | 8080 | homarr |
| 3000 | grafana | | 8081 | nextcloud |
| 3001 | uptime-kuma | | 8086 | podgrab |
| 4533 | navidrome | | 8087 | audiobookshelf |
| 5055 | jellyseerr | | 8090 | filebrowser |
| 6767 | bazarr | | 8096 | jellyfin |
| 6881 | deluge peers | | 8112 | deluge web |
| 58846 | deluge daemon | | 8191 | flaresolverr |
| 8686 | lidarr | | 8989 | sonarr |
| 9000 | portainer | | 9696 | prowlarr |
| 9898 | open-webui | | 9925 | mealie |

## Host services (outside Docker)

All three are pacman packages + systemd units, not containers.

### Samba (LAN file sharing)

- Packages/units: `samba` → `smb.service` + `nmb.service` (both enabled)
- Config: `/etc/samba/smb.conf`. Effective shares:
  - `[fileShare]` → `/home/pi`, **guest ok**, `force user = pi`,
    create/directory masks 0777 (any LAN device can read/write everything)
  - `[homes]` → per-user home, not browseable, `valid users = %S`
- Recreate: `sudo pacman -S samba`, restore `smb.conf`,
  `sudo systemctl enable --now smb nmb`
- Note: guest-writable access to the whole home dir is a deliberate choice —
  nothing on this network is internet-exposed; remote access is Tailscale-only
  (authenticated devices). Revisit only if a port forward or untrusted LAN
  device is ever introduced.

### code-server (VS Code in browser)

- Package/unit: `code-server` → `code-server.service` (runs as user `pi`)
- Config: `/etc/code-server/config.yaml` — binds `0.0.0.0:8443`,
  `auth: password`, `cert: false`; unit file sets the password via `Environment=PASSWORD=<redacted>`
- Recreate: `sudo pacman -S code-server`, restore config,
  `sudo systemctl enable --now code-server`
- HTTP-only is fine under the current model (no port
  forwarding anywhere; reachable only from LAN/tailnet) — just never expose it.

### Tailscale (remote access VPN)

- Package/unit: `tailscale` → `tailscaled.service`
- This node: hostname **arch-server**, tailnet IP `100.127.42.118`,
  advertises **exit node** + **subnet route `192.168.1.0/24`** (gives remote
  devices access to the whole LAN, incl. pihole DNS and every service port)
- Recreate:
  ```bash
  sudo pacman -S tailscale
  sudo systemctl enable --now tailscaled
  sudo tailscale up --advertise-exit-node --advertise-routes=192.168.1.0/24
  # then approve the routes/exit-node in the Tailscale admin console
  ```
- Login: the user's Google account; no auth keys stored on disk.

## Known quirks / gotchas

- `docker_update_and_prune.sh` pulls `:latest` weekly for most apps — DB images
  are version-pinned on purpose; keep them pinned.
- During the 02:00 backup window Nextcloud may briefly show "Backups" as
  unavailable (fresh restic files are 0600 until the post-run chmod). Self-heals;
  `docker exec -u www-data nextcloud php occ files_external:verify 1` resets it.
- Postgres collation: after major glibc bumps in DB images, run per DB:
  `REINDEX DATABASE <db>; ALTER DATABASE <db> REFRESH COLLATION VERSION;`
- Filebrowser mounts all of `/home/pi`; portainer/homarr/kuma/dozzle mount the
  docker socket (kuma/dozzle read-only). Conscious trade-offs, revisit if unused.
- Vaultwarden: signups disabled; add users via admin panel (`/admin`, token =
  contents of `secrets/VAULTWARDER_ADMIN_TOKEN`).

## What is NOT in git (restore from restic/off-machine copies)

- `secrets/sources/*.env`, generated `secrets/*` files
- `env/*.env` (immich paths)
- `scripts/.env` (Telegram bot), `scripts/.kuma.env` (push tokens),
  `scripts/.zipPass`, `scripts/backup/.restic.env` (**repo password!**)
- All of `/home/pi/apps/*` (live service data)
