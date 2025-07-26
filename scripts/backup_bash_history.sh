#!/bin/bash

SRC="$HOME/.bash_history"
DST="/home/pi/Storage/backups/.bash_history"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "📋 Starting bash history backup: $(date)"
  cp "$SRC" "$DST"
  echo "✅ Backup completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
