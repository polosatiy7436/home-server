#!/bin/bash

DOCKER_DIR="/home/pi/docker"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

cd "$DOCKER_DIR" || {
  echo "❌ Failed to cd to $DOCKER_DIR"
  exit 1
}

{
  echo "🧹 Starting Docker cleanup: $(date)"
  /usr/bin/docker system prune -af
  /usr/bin/docker image prune -af
  /usr/bin/docker system prune -af --volumes
  /usr/bin/docker system df
  echo "✅ Docker cleanup completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
