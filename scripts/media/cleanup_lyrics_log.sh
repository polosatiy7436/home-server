#!/bin/bash
source /home/pi/scripts/lib/notify.sh

LOG_FILE="/home/pi/lyrics_fetch.log"

cleanup_lyrics_log() {
  echo "🗑️ Starting log cleanup: $(date)"
  rm -f "$LOG_FILE"
  echo "✅ Log cleanup done: $(date)"
}

run_with_notify cleanup_lyrics_log
