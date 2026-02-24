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

### Configure waydroid
systemctl enable waydroid-container.service || systemctl enable waydroid-container

# Make waydroid directories writable for runtime configuration and troubleshooting
mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/waydroid.conf << 'EOF'
d /var/lib/waydroid 0755 root root -
d /var/lib/waydroid/cache_http 0755 root root -
d /var/lib/waydroid/lxc 0755 root root -
d /var/lib/waydroid/data 0755 root root -
d /var/lib/waydroid/images 0755 root root -
EOF

# Create first-boot initialization service for Waydroid with enhanced error handling
cat > /usr/lib/systemd/system/waydroid-first-init.service << 'EOF'
[Unit]
Description=Initialize Waydroid with GAPPS on first boot
Wants=network-online.target waydroid-container.service
After=network-online.target waydroid-container.service
ConditionPathExists=!/var/lib/waydroid/.initialized

[Service]
Type=oneshot
ExecStartPre=/usr/bin/mkdir -p /var/lib/waydroid
ExecStart=/usr/bin/bash -c '\
  WAYDROID_LOG="/var/log/waydroid-init.log"; \
  exec 1>>"$WAYDROID_LOG" 2>&1; \
  echo "[$(date)] Starting Waydroid initialization"; \
  \
  GAPPS_SYSTEM="https://ota.waydro.id/system"; \
  GAPPS_VENDOR="https://ota.waydro.id/vendor"; \
  VANILLA_SYSTEM="https://amstel-dev.github.io/ota/system"; \
  VANILLA_VENDOR="https://amstel-dev.github.io/ota/vendor"; \
  \
  echo "[$(date)] Attempting to initialize with official GAPPS server"; \
  if /usr/bin/waydroid init -s GAPPS -f -c "$GAPPS_SYSTEM" -v "$GAPPS_VENDOR" 2>"$WAYDROID_LOG.tmp"; then \
    echo "[$(date)] SUCCESS: Official GAPPS server used"; \
    GAPPS_INSTALLED="1"; \
  else \
    echo "[$(date)] WARNING: Official GAPPS server failed, falling back to vanilla"; \
    if /usr/bin/waydroid init -f -c "$VANILLA_SYSTEM" -v "$VANILLA_VENDOR" 2>"$WAYDROID_LOG.tmp"; then \
      echo "[$(date)] SUCCESS: Vanilla server used, will install GApps automatically"; \
      GAPPS_INSTALLED="0"; \
    else \
      echo "[$(date)] ERROR: Both servers failed"; \
      cat "$WAYDROID_LOG.tmp" >> "$WAYDROID_LOG"; \
      exit 1; \
    fi; \
  fi; \
  \
  if [[ ! -f /var/lib/waydroid/lxc/waydroid/config ]]; then \
    echo "[$(date)] ERROR: LXC config file not created"; \
    exit 1; \
  fi; \
  \
  echo "[$(date)] Fixing LXCARCH placeholder"; \
  /usr/bin/sed -i "s/LXCARCH/x86_64/g" /var/lib/waydroid/lxc/waydroid/config; \
  \
  echo "[$(date)] Configuring waydroid.prop"; \
  if [[ -f /var/lib/waydroid/waydroid.prop ]]; then \
    /usr/bin/grep -q "net.dns1" /var/lib/waydroid/waydroid.prop || echo "net.dns1=8.8.8.8" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "net.dns2" /var/lib/waydroid/waydroid.prop || echo "net.dns2=8.8.4.4" >> /var/lib/waydroid/waydroid.prop; \
    if [[ "$GAPPS_INSTALLED" == "0" ]]; then \
      /usr/bin/grep -q "ro.waydroid.skipgappsinstall" /var/lib/waydroid/waydroid.prop || echo "ro.waydroid.skipgappsinstall=0" >> /var/lib/waydroid/waydroid.prop; \
    fi; \
  fi; \
  \
  if [[ -f /var/lib/waydroid/images/system.img && -f /var/lib/waydroid/images/vendor.img && -f /var/lib/waydroid/lxc/waydroid/config ]]; then \
    if ! /usr/bin/grep -q "LXCARCH" /var/lib/waydroid/lxc/waydroid/config; then \
      echo "[$(date)] All validation checks passed"; \
      /usr/bin/touch /var/lib/waydroid/.initialized; \
      if [[ "$GAPPS_INSTALLED" == "0" ]]; then \
        echo "[$(date)] NOTE: Vanilla image installed - GApps will be installed on first session start"; \
      fi; \
      echo "[$(date)] Waydroid initialization complete"; \
      exit 0; \
    fi; \
  fi; \
  \
  echo "[$(date)] ERROR: Validation checks failed"; \
  exit 1'
RemainAfterExit=yes
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl enable waydroid-first-init.service

# Create helper script for waydroid status monitoring
cat > /usr/bin/waydroid-check << 'CHECKEOF'
#!/bin/bash
set -e

echo "Checking Waydroid status..."

# Check container state
if lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>/dev/null | grep -qi frozen; then
  echo "ERROR: Container is FROZEN"
  echo "Attempting to unfreeze..."
  lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid
  exit 1
fi

# Check for waydroid errors in journal
if journalctl -u waydroid-container.service -n 50 --no-pager 2>/dev/null | grep -i "error\|failed\|abort"; then
  echo "ERROR: Waydroid service errors detected in journal"
  journalctl -u waydroid-container.service -n 50 --no-pager
  exit 1
fi

# Check if session is running
if ! waydroid status 2>/dev/null | grep -qi "session.*running"; then
  echo "WARNING: Waydroid session not running"
  echo "Starting session..."
  waydroid session start
fi

echo "Waydroid check complete"
CHECKEOF

chmod +x /usr/bin/waydroid-check

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
Environment=AUTO_REBOOT=1
ExecStart=/usr/bin/timeout 90 /usr/bin/bash /usr/bin/switch-image-by-gpu.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable bootc-gpu-auto-switch.service

### Enable automatic bootc updates
systemctl enable bootc-fetch-apply-updates.timer

### Remove restrictive polkit rules
rm -f /etc/polkit-1/rules.d/*package* /etc/polkit-1/rules.d/*rpm*
