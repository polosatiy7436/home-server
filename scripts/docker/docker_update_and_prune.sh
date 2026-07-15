#!/bin/bash
source /home/pi/scripts/lib/notify.sh

DOCKER_DIR="/home/pi/docker"

cd "$DOCKER_DIR" || {
  echo "❌ Failed to cd to $DOCKER_DIR"
  exit 1
}

docker_update_and_prune() {
  echo "🚀 Starting Docker update & prune: $(date)"
  /usr/bin/docker compose pull
  /usr/bin/docker compose up -d
  /usr/bin/docker system prune -a -f
  echo "✅ Docker update & prune completed: $(date)"
}

run_with_notify docker_update_and_prune
