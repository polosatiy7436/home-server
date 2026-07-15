#!/bin/bash
source /home/pi/scripts/lib/notify.sh

system_update() {
  echo "📦 Starting system update: $(date)"
  /usr/bin/sudo /usr/bin/pacman -Syu --noconfirm
  echo "🔄 Updating AUR packages"
  /usr/bin/yay -Syu --noconfirm
  echo "✅ Update completed: $(date)"
}

run_with_notify system_update
