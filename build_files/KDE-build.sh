#!/usr/bin/bash

# Ensure DEBUG_LOG is always set
: "${DEBUG_LOG:=/dev/null}"

set -ouex pipefail

### Install required packages
dnf5 install -y \
  snapd \
  papirus-icon-theme \
  network-manager-applet

### Remove GNOME packages
# List all GNOME packages and remove them
dnf5 remove -y \
  $(rpm -qa | grep -E '^(gnome-|evolution-)') || true

### Configure snapd
mkdir -p /var/lib/snapd
ln -sfn /var/lib/snapd/snap /snap
systemctl enable snapd.socket
if systemctl list-unit-files | grep -q '^snapd.apparmor.service'; then
  systemctl enable snapd.apparmor.service
fi


mkdir -p /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
chmod 0755 /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
chown root:root /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
systemctl enable waydroid-first-init.service || true
systemctl enable waydroid-watchdog.timer || true
echo -e "\nDebug log saved to: $DEBUG_LOG"

### Configure GPU auto-switching
install -m 0755 /ctx/scripts/switch-image-by-gpu.sh /usr/bin/switch-image-by-gpu.sh


cat > /usr/lib/systemd/system/bootc-gpu-auto-switch.service << 'EOF'
[Unit]
Description=Auto switch bootc image based on GPU vendor at boot
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
TimeoutStartSec=90
ExecStart=/usr/bin/timeout 90 /usr/bin/bash /usr/bin/switch-image-by-gpu.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable bootc-gpu-auto-switch.service

### Enable automatic bootc updates
systemctl enable bootc-fetch-apply-updates.timer

### Remove restrictive polkit rules
rm -f /etc/polkit-1/rules.d/*package* /etc/polkit-1/rules.d/*rpm*

### Customize OS identification
# Update os-release to show Bazzite-With-Snapd KDE instead of Bazzite
sed -i 's/^NAME=.*/NAME="Bazzite-With-Snapd"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Bazzite-With-Snapd KDE"/' /etc/os-release

dnf5 install -y tigervnc-server plasma-workspace plasma-desktop xterm
dnf5 clean all