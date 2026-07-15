#!/bin/bash
source /home/pi/scripts/lib/notify.sh

DST="/home/pi/Storage/backups/crontab.backup"

backup_crontab() {
  echo "📋 Starting crontab backup: $(date)"
  crontab -l > "$DST"
  echo "✅ Backup completed: $(date)"
}

run_with_notify backup_crontab
