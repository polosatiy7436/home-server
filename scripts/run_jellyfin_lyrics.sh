#!/bin/bash

SCRIPT="/home/pi/apps/Jellyfin-lyrics/main.py"
PYTHON="/usr/bin/python3"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "🎵 Starting Jellyfin-lyrics script: $(date)"
  $PYTHON "$SCRIPT"
  echo "✅ Jellyfin-lyrics script finished: $(date)"
} 2>&1 | $PYTHON "$TELEGRAM_SCRIPT"
