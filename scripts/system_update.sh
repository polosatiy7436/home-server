#!/bin/bash

TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

{
  echo "📦 Starting system update: $(date)"
  /usr/bin/sudo /usr/bin/apt update
  /usr/bin/sudo /usr/bin/apt -y upgrade
  echo "✅ Update completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
