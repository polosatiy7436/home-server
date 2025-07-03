#!/bin/bash
REMOTE_USER="Maksim_Uladyka"
REMOTE_IP="192.168.1.33"
REMOTE_DIR="/Users/Maksim_Uladyka/Documents/backups"
BACKUP_DIR="/home/pi/Storage/backups/vaultwarden"
DATE=$(date +%Y-%m-%d)

# Stop
docker-compose -f /home/pi/docker/docker-compose.yml stop vaultwarden

# Create archive
tar -czvf "$BACKUP_DIR/vaultwarden-$DATE.tar.gz" /home/pi/apps/vaultwarden/data

# Backup to Mac
rsync -avz "$BACKUP_DIR/vaultwarden-$DATE.tar.gz" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"

# Start
docker-compose -f /home/pi/docker/docker-compose.yml start vaultwarden

# 30 days retention
find "$BACKUP_DIR" -type f -name "vaultwarden-*.tar.gz" -mtime +30 -delete
ssh "$REMOTE_USER@$REMOTE_IP" "find $REMOTE_DIR -type f -name 'vaultwarden-*.tar.gz*' -mtime +30 -delete"
