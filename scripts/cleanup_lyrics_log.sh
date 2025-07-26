#!/bin/bash

LOG_FILE="/home/pi/scripts/lyrics_fetch.log"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "🗑️ Starting log cleanup: $(date)"
  rm -f "$LOG_FILE"
  echo "✅ Log cleanup done: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
