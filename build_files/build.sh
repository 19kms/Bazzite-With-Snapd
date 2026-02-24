#!/usr/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images.

dnf5 install -y \
  curl \
  unzip \
  snapd \
  gnome-shell \
  gdm \
  gnome-control-center \
  gnome-terminal \
  nautilus \
  gnome-session \
  gnome-settings-daemon \
  gnome-software \
  waydroid

### GNOME extensions

EXTDIR="/usr/share/gnome-shell/extensions"
mkdir -p "$EXTDIR"

install_extension_zip() {
  local archive_url="$1"
  local unpack_dir="$2"
  local extension_id="$3"

  local archive_path="/tmp/${extension_id}.zip"
  curl -fsSL -o "$archive_path" "$archive_url"
  unzip -q "$archive_path" -d /tmp/
  cp -r "/tmp/${unpack_dir}/${extension_id}" "$EXTDIR/"
}

install_extension_zip "https://github.com/aryan02420/Logo-menu/archive/refs/heads/main.zip" "Logo-menu-main" "logomenu@aryan_k"
install_extension_zip "https://github.com/hermes83/compiz-windows-effect/archive/refs/heads/main.zip" "compiz-windows-effect-main" "compiz-windows-effect@hermes83.github.com"
install_extension_zip "https://github.com/hermes83/compiz-alike-magic-lamp-effect/archive/refs/heads/main.zip" "compiz-alike-magic-lamp-effect-main" "compiz-alike-magic-lamp-effect@hermes83.github.com"
install_extension_zip "https://github.com/jdoda/hotedge/archive/refs/heads/main.zip" "hotedge-main" "hotedge@jonathan.jdoda.ca"
install_extension_zip "https://github.com/tiagoporsch/restartto/archive/refs/heads/main.zip" "restartto-main" "restartto@tiagoporsch.github.io"
install_extension_zip "https://github.com/ubuntu/gnome-shell-extension-appindicator/archive/refs/heads/main.zip" "gnome-shell-extension-appindicator-main" "appindicatorsupport@rgcjonas.gmail.com"
install_extension_zip "https://github.com/skullbite/gnome-add-to-steam/archive/refs/heads/main.zip" "gnome-add-to-steam-main" "add-to-steam@pupper.space"
install_extension_zip "https://github.com/eonpatapon/gnome-shell-extension-caffeine/archive/refs/heads/master.zip" "gnome-shell-extension-caffeine-master" "caffeine@patapon.info"
install_extension_zip "https://github.com/SchegolevIvan/burn-my-windows/archive/refs/heads/main.zip" "burn-my-windows-main" "burn-my-windows@schneegans.github.com"
install_extension_zip "https://github.com/Schneegans/Desktop-Cube/archive/refs/heads/main.zip" "Desktop-Cube-main" "desktop-cube@schneegans.github.com"
install_extension_zip "https://github.com/aunetx/blur-my-shell/archive/refs/heads/master.zip" "blur-my-shell-master" "blur-my-shell@aunetx"
install_extension_zip "https://github.com/kolunmi/bazaar-integration/archive/refs/heads/main.zip" "bazaar-integration-main" "bazaar-integration@kolunmi.github.io"

# Set default enabled extensions system-wide via dconf defaults.
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-gnome-shell-extensions << 'EOF'
[org/gnome/shell]
enabled-extensions=['hotedge@jonathan.jdoda.ca','appindicatorsupport@rgcjonas.gmail.com','blur-my-shell@aunetx','logomenu@aryan_k','restartto@tiagoporsch.github.io']
EOF

dconf update

### Runtime services and compatibility setup

# Required for snapd runtime support.
mkdir -p /var/lib/snapd
ln -sfn /var/lib/snapd/snap /snap
systemctl enable snapd.socket
if systemctl list-unit-files | grep -q '^snapd.apparmor.service'; then
  systemctl enable snapd.apparmor.service
fi

# Enable waydroid runtime service.
systemctl enable waydroid-container.service || systemctl enable waydroid-container

# Install GPU-aware image switch helper and run it automatically on first boot.
install -D -m 0755 /ctx/scripts/switch-image-by-gpu.sh /usr/local/bin/switch-image-by-gpu.sh

cat > /usr/lib/systemd/system/bootc-gpu-auto-switch.service << 'EOF'
[Unit]
Description=Auto switch bootc image based on GPU vendor on first boot
Wants=network-online.target
After=network-online.target
ConditionFirstBoot=yes

[Service]
Type=oneshot
TimeoutStartSec=90
Environment=AUTO_REBOOT=1
ExecStart=/usr/bin/timeout 90 /usr/bin/bash /usr/local/bin/switch-image-by-gpu.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable bootc-gpu-auto-switch.service

# Remove restrictive package-installation polkit rules.
rm -f /etc/polkit-1/rules.d/*package* /etc/polkit-1/rules.d/*rpm*
