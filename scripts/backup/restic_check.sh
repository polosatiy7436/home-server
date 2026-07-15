#!/bin/bash
# restic_check.sh — monthly repository integrity check (reads 5% of data).
source /home/pi/scripts/lib/notify.sh
source /home/pi/scripts/backup/.restic.env

RESTIC=/home/pi/bin/restic

restic_check() {
  echo "🔍 Starting restic repository check: $(date)"
  $RESTIC check --read-data-subset=5%
  echo "✅ Repository check completed: $(date)"
}

run_with_notify restic_check
