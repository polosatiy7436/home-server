#!/bin/bash
# restic_backup.sh — nightly backup into a local restic repo that is shared
# to the user's devices through Nextcloud (external storage "Backups").
# 1. dumps all databases  2. restic snapshot  3. prune per retention policy
# 4. make repo world-readable so the Nextcloud container (www-data) can serve it
source /home/pi/scripts/lib/notify.sh
source /home/pi/scripts/backup/.restic.env

RESTIC=/home/pi/bin/restic

# never run two instances at once (concurrent prune fails on the repo lock)
exec 9>/tmp/restic_backup.flock
if ! flock -n 9; then
  echo "⚠️ restic_backup already running, skipping this invocation" | python3 "$TELEGRAM_SCRIPT"
  exit 0
fi

restic_backup() {
  echo "💾 Starting backup: $(date)"

  # clear leftover locks from crashed/killed runs (only removes stale ones)
  $RESTIC unlock

  local dump_rc=0
  /home/pi/scripts/backup/dump_databases.sh || { dump_rc=$?; echo "⚠️ Continuing backup despite dump failure"; }

  # /home/pi/apps/nextcloud/data is excluded: those files already live on 3
  # devices via Nextcloud sync. Its config/ and the DB dump ARE backed up.
  $RESTIC backup \
    /home/pi/apps \
    /home/pi/docker \
    /home/pi/scripts \
    /home/pi/Storage/backups/db \
    /home/pi/Storage/backups/crontab.backup \
    --exclude /home/pi/apps/nextcloud/data \
    --exclude /home/pi/apps/immich/postgres \
    --exclude /home/pi/apps/immich/model-cache \
    --exclude /home/pi/apps/immich/upload/thumbs \
    --exclude /home/pi/apps/nextcloud_postgres \
    --exclude /home/pi/apps/mealie_postgres \
    --exclude /home/pi/apps/bookstack_db \
    --exclude /home/pi/apps/ngnix_proxy/mysql \
    --exclude /home/pi/apps/vaultwarden/data/icon_cache \
    --exclude /home/pi/apps/jellyfin/config/cache \
    --exclude /home/pi/apps/jellyfin/config/transcodes \
    --exclude-caches \
    --one-file-system

  echo "🧹 Pruning old snapshots (7d/4w/6m)"
  $RESTIC forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

  # Nextcloud's www-data (uid 33) must be able to read the repo to sync it out
  chmod -R u+rwX,go+rX "$RESTIC_REPOSITORY"

  $RESTIC snapshots --compact | tail -5
  echo "✅ Backup completed: $(date)"
  # a failed dump still yields a snapshot, but must show as 'down' in Kuma
  return "$dump_rc"
}

run_with_notify restic_backup
