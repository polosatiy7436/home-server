#!/bin/bash

SRC="/var/spool/cron/crontabs/pi"
DST="/home/pi/Storage/backups/crontab.backup"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "📋 Starting crontab backup: $(date)"
  /usr/bin/sudo /usr/bin/cp "$SRC" "$DST"
  echo "✅ Backup completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
