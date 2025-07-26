#!/bin/bash

DOCKER_DIR="/home/pi/docker"
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"

cd "$DOCKER_DIR" || {
  echo "❌ Failed to cd to $DOCKER_DIR"
  exit 1
}

{
  echo "🚀 Starting Docker update & prune: $(date)"
  /usr/bin/docker compose pull
  /usr/bin/docker compose up -d
  /usr/bin/docker system prune -a -f
  echo "✅ Docker update & prune completed: $(date)"
} 2>&1 | /usr/bin/python3 "$TELEGRAM_SCRIPT"
