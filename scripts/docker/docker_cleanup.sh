#!/bin/bash
source /home/pi/scripts/lib/notify.sh

DOCKER_DIR="/home/pi/docker"

cd "$DOCKER_DIR" || {
  echo "❌ Failed to cd to $DOCKER_DIR"
  exit 1
}

docker_cleanup() {
  echo "🧹 Starting Docker cleanup: $(date)"
  /usr/bin/docker system prune -af
  /usr/bin/docker image prune -af
  /usr/bin/docker system prune -af --volumes
  /usr/bin/docker system df
  echo "✅ Docker cleanup completed: $(date)"
}

run_with_notify docker_cleanup
