#!/usr/bin/env bash
# toggle-immutability.sh
# Toggle immutability for NixoraOS

set -e

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi


IMMUTABLE_FLAG="/etc/nixoraos-immutable"
MUTABLE_TRACK_FILE="/var/lib/nixoraos/mutable-changes.log"


if [[ -f "$IMMUTABLE_FLAG" ]]; then
  echo "Disabling immutability..."
  rm "$IMMUTABLE_FLAG"
  echo "Root filesystem is now writable."
  # Start tracking changes
  mkdir -p "$(dirname "$MUTABLE_TRACK_FILE")"
  echo "" > "$MUTABLE_TRACK_FILE"
  echo "Tracking all changes in: $MUTABLE_TRACK_FILE"
  # Setup inotifywait to track changes in background (simple version)
  nohup inotifywait -m -r -e create,modify,delete --format '%w%f' / | grep --line-buffered -v "/proc/" | grep --line-buffered -v "/sys/" | grep --line-buffered -v "$MUTABLE_TRACK_FILE" >> "$MUTABLE_TRACK_FILE" 2>/dev/null &
  echo $! > /var/run/nixoraos-mutable-inotify.pid
else
  echo "Enabling immutability..."
  touch "$IMMUTABLE_FLAG"
  echo "Root filesystem is now immutable (read-only)."
  # Stop tracking changes
  if [[ -f /var/run/nixoraos-mutable-inotify.pid ]]; then
    kill $(cat /var/run/nixoraos-mutable-inotify.pid) 2>/dev/null || true
    rm -f /var/run/nixoraos-mutable-inotify.pid
  fi
fi

# Example: remount root as read-only or writable
if [[ -f "$IMMUTABLE_FLAG" ]]; then
  mount -o remount,ro /
else
  mount -o remount,rw /
fi

exit 0
