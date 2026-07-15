#!/bin/bash
source /home/pi/scripts/lib/notify.sh

REMOTE_USER="polo"
REMOTE_IP="192.168.1.70"
REMOTE_DIR="/home/polo/backups"
BACKUP_DIR="/home/pi/Storage/backups/vaultwarden"
DATE=$(date +%Y-%m-%d)
PASSFILE="/home/pi/scripts/.zipPass"

# Read password
ZIP_PASSWORD=$(<"$PASSFILE")

backup_vaultwarden() {
  echo "📦 Starting Vaultwarden backup: $(date)"

  # Stop Vaultwarden container
  docker compose -f /home/pi/docker/docker-compose.yml stop vaultwarden

  # Create archive excluding icon_cache
  TAR_FILE="$BACKUP_DIR/vaultwarden-$DATE.tar.gz"
  ZIP_FILE="$BACKUP_DIR/vaultwarden-$DATE.zip"

  tar -czvf "$TAR_FILE" \
    --exclude='apps/vaultwarden/data/icon_cache' \
    /home/pi/apps/vaultwarden/data

  # Protect with password (ZIP)
  zip -j -P "$ZIP_PASSWORD" "$ZIP_FILE" "$TAR_FILE"

  # Sync ZIP archive to remote Mac
  rsync -avz "$ZIP_FILE" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"

  # Start Vaultwarden container
  docker compose -f /home/pi/docker/docker-compose.yml start vaultwarden

  # Remove local backups older than 30 days
  find "$BACKUP_DIR" -type f \( -name "vaultwarden-*.tar.gz" -o -name "vaultwarden-*.zip" \) -mtime +30 -delete

  # Remove remote backups older than 30 days
  ssh "$REMOTE_USER@$REMOTE_IP" "find '$REMOTE_DIR' -type f -name 'vaultwarden-*.zip' -mtime +30 -delete"

  echo "✅ Vaultwarden backup completed: $(date)"
}

run_with_notify backup_vaultwarden
