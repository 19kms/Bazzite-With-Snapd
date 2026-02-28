#!/usr/bin/env bash
set -e

# 1. Stage updates (example for rpm-ostree)
rpm-ostree upgrade --stage

# 2. Notify user
echo "A new system update is ready, To apply the update, press yes. If you don't want to update now, select no"

# 3. Wait for user confirmation
read -p "Reboot now? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    systemctl reboot
else
    echo "Update staged. Please reboot to apply the update."
fi