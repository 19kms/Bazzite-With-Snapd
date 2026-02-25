#!/usr/bin/bash

set -ouex pipefail

### Install required packages
dnf5 install -y \
  snapd \
  papirus-icon-theme \
  gnome-shell-extension-appindicator \
  network-manager-applet

### Remove KDE/Plasma packages
# List all KDE/Plasma packages and remove them
dnf5 remove -y \
  $(rpm -qa | grep -E '^(kde-|plasma-|kwin|konsole|dolphin)') || true

### Install GNOME extensions
EXTDIR="/usr/share/gnome-shell/extensions"
mkdir -p "$EXTDIR"

source /ctx/gnome-extension-refs.env

install_extension_from_repo() {
  local repo="$1"
  local ref="$2"
  local extension_id="$3"
  local fallback_ref="${4:-}"

  local archive_url="https://github.com/${repo}/archive/${ref}.zip"
  local archive_root="/tmp/ext-${extension_id}"
  local archive_path="${archive_root}.zip"

  if ! curl -fsSL -o "$archive_path" "$archive_url"; then
    if [[ -n "$fallback_ref" ]]; then
      local fallback_url="https://github.com/${repo}/archive/${fallback_ref}.zip"
      echo "Primary download failed for ${extension_id}, trying fallback ref ${fallback_ref}"
      if ! curl -fsSL -o "$archive_path" "$fallback_url"; then
        echo "Skipping extension ${extension_id}: failed to download"
        return 0
      fi
    else
      echo "Skipping extension ${extension_id}: failed to download"
      return 0
    fi
  fi

  rm -rf "$archive_root"
  mkdir -p "$archive_root"

  if ! unzip -q "$archive_path" -d "$archive_root"; then
    echo "Skipping extension ${extension_id}: failed to unzip"
    return 0
  fi

  local extension_path
  extension_path="$(find "$archive_root" -type d -name "$extension_id" -print -quit)"
  if [[ -z "$extension_path" ]]; then
    echo "Skipping extension ${extension_id}: not found in archive"
    return 0
  fi

  cp -r "$extension_path" "$EXTDIR/"

  if [[ -d "$EXTDIR/$extension_id/schemas" ]]; then
    glib-compile-schemas "$EXTDIR/$extension_id/schemas" || true
  fi
}

# Install GNOME Shell extensions
install_extension_from_repo "$LOGO_MENU_REPO" "$LOGO_MENU_REF" "logomenu@aryan_k" "$LOGO_MENU_FALLBACK_REF"
install_extension_from_repo "$COMPIZ_WINDOWS_EFFECT_REPO" "$COMPIZ_WINDOWS_EFFECT_REF" "compiz-windows-effect@hermes83.github.com"
install_extension_from_repo "$COMPIZ_MAGIC_LAMP_REPO" "$COMPIZ_MAGIC_LAMP_REF" "compiz-alike-magic-lamp-effect@hermes83.github.com"
install_extension_from_repo "$HOTEDGE_REPO" "$HOTEDGE_REF" "hotedge@jonathan.jdoda.ca"
install_extension_from_repo "$RESTARTTO_REPO" "$RESTARTTO_REF" "restartto@tiagoporsch.github.io"
install_extension_from_repo "$APPINDICATOR_REPO" "$APPINDICATOR_REF" "appindicatorsupport@rgcjonas.gmail.com"
install_extension_from_repo "$ADD_TO_STEAM_REPO" "$ADD_TO_STEAM_REF" "add-to-steam@pupper.space"
install_extension_from_repo "$CAFFEINE_REPO" "$CAFFEINE_REF" "caffeine@patapon.info"
install_extension_from_repo "$BURN_MY_WINDOWS_REPO" "$BURN_MY_WINDOWS_REF" "burn-my-windows@schneegans.github.com"
install_extension_from_repo "$DESKTOP_CUBE_REPO" "$DESKTOP_CUBE_REF" "desktop-cube@schneegans.github.com"
install_extension_from_repo "$BLUR_MY_SHELL_REPO" "$BLUR_MY_SHELL_REF" "blur-my-shell@aunetx"
install_extension_from_repo "$BAZAAR_INTEGRATION_REPO" "$BAZAAR_INTEGRATION_REF" "bazaar-integration@kolunmi.github.io"

### Configure GNOME defaults
mkdir -p /etc/dconf/db/local.d

cat > /etc/dconf/db/local.d/00-gnome-shell-extensions << 'EOF'
[org/gnome/shell]
enabled-extensions=['hotedge@jonathan.jdoda.ca','appindicatorsupport@rgcjonas.gmail.com','blur-my-shell@aunetx','logomenu@aryan_k','restartto@tiagoporsch.github.io']
EOF

cat > /etc/dconf/db/local.d/01-gnome-ui-defaults << 'EOF'
[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'

[org/gnome/desktop/interface]
icon-theme='Papirus'
color-scheme='prefer-dark'
gtk-theme='Adwaita'
EOF

dconf update

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
systemctl enable waydroid-first-init.service
systemctl enable waydroid-watchdog.timer
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
# Update os-release to show Bazzite-With-Snapd GNOME instead of Bazzite
sed -i 's/^NAME=.*/NAME="Bazzite-With-Snapd"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Bazzite-With-Snapd GNOME"/' /etc/os-release
