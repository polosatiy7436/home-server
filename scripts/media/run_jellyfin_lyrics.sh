#!/bin/bash
source /home/pi/scripts/lib/notify.sh

SCRIPT="/home/pi/apps/Jellyfin-lyrics/main.py"

run_jellyfin_lyrics() {
  echo "🎵 Starting Jellyfin-lyrics script: $(date)"
  /home/pi/apps/Jellyfin-lyrics/bin/python3 "$SCRIPT"
  echo "✅ Jellyfin-lyrics script finished: $(date)"
}

run_with_notify run_jellyfin_lyrics
