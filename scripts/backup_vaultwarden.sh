#!/bin/bash

REMOTE_USER="Maksim_Uladyka"
REMOTE_IP="192.168.1.6"
REMOTE_DIR="/Users/Maksim_Uladyka/Documents/backups"
BACKUP_DIR="/home/pi/Storage/backups/vaultwarden"
DATE=$(date +%Y-%m-%d)
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "📦 Starting system update: $(date)"

  # Stop Vaultwarden container
  docker-compose -f /home/pi/docker/docker-compose.yml stop vaultwarden

  # Create archive excluding icon_cache
  tar -czvf "$BACKUP_DIR/vaultwarden-$DATE.tar.gz" \
    --exclude='apps/vaultwarden/data/icon_cache' \
    /home/pi/apps/vaultwarden/data

  # Sync archive to remote Mac
  rsync -avz "$BACKUP_DIR/vaultwarden-$DATE.tar.gz" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"

  # Start Vaultwarden container
  docker-compose -f /home/pi/docker/docker-compose.yml start vaultwarden

  # Remove backups older than 30 days locally
  find "$BACKUP_DIR" -type f -name "vaultwarden-*.tar.gz" -mtime +30 -delete

  # Remove backups older than 30 days remotely
  ssh "$REMOTE_USER@$REMOTE_IP" "find '$REMOTE_DIR' -type f -name 'vaultwarden-*.tar.gz*' -mtime +30 -delete"

  echo "✅ Vaultwarden backup completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
