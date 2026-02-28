# Ensure /usr/sbin/dnf is a working wrapper to dnf5
cat <<'EOF' > /usr/sbin/dnf
#!/usr/bin/bash
exec /usr/bin/dnf5 "$@"
EOF
chmod +x /usr/sbin/dnf
# Ensure DEBUG_LOG is always set
: "${DEBUG_LOG:=/dev/null}"
#!/usr/bin/env bash
# Shared build logic for GNOME and KDE images.
# Automates all Waydroid setup, Play Store, Aurora Store, and recovery steps.

set -ouex pipefail

### Ensure dnf is installed and functional
if ! rpm -q dnf >/dev/null 2>&1; then
  dnf5 install -y dnf
fi

# Install Waydroid if not present
if ! rpm -q waydroid >/dev/null 2>&1; then
  dnf5 install -y waydroid
fi

# KDE handler placeholder (add KDE-specific tweaks here)
if [[ "$XDG_CURRENT_DESKTOP" =~ KDE|Plasma ]]; then
  echo "[INFO] KDE detected: add KDE-specific Waydroid tweaks here."
  # Example: appindicator fixes, session tweaks, etc.
  # (No KDE-specific tweaks found yet)
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

mkdir -p /var/lib/waydroid /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
chmod 0755 /var/lib/waydroid /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
chown root:root /var/lib/waydroid /var/lib/waydroid/cache_http /var/lib/waydroid/lxc /var/lib/waydroid/data /var/lib/waydroid/images
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

  # Pre-install Aurora Store APK
  AURORA_URL="https://f-droid.org/repo/com.aurora.store_73.apk"; \
  AURORA_APK="/var/lib/waydroid/data/aurora-store.apk"; \
  echo "[$(date)] Downloading Aurora Store APK from $AURORA_URL"; \
  if /usr/bin/wget -O "$AURORA_APK" "$AURORA_URL"; then \
    echo "[$(date)] Installing Aurora Store APK"; \
    /usr/bin/waydroid app install "$AURORA_APK" || echo "[$(date)] WARNING: Aurora Store APK install failed"; \
  else \
    echo "[$(date)] WARNING: Failed to download Aurora Store APK"; \
  fi; \
  \
  echo "[$(date)] Configuring waydroid.prop"; \
  if [[ -f /var/lib/waydroid/waydroid.prop ]]; then \
    \
    # Network configuration \
    /usr/bin/grep -q "net.dns1" /var/lib/waydroid/waydroid.prop || echo "net.dns1=8.8.8.8" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "net.dns2" /var/lib/waydroid/waydroid.prop || echo "net.dns2=8.8.4.4" >> /var/lib/waydroid/waydroid.prop; \
    \
    # WiFi and Network properties for Play Services \
    /usr/bin/grep -q "persist.waydroid.fake_wifi" /var/lib/waydroid/waydroid.prop || echo "persist.waydroid.fake_wifi=true" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "net.interfaces" /var/lib/waydroid/waydroid.prop || echo "net.interfaces=lo,eth0" >> /var/lib/waydroid/waydroid.prop; \
    \
    # Device identification for Play Services certification \
    /usr/bin/grep -q "ro.com.google.clientidbase" /var/lib/waydroid/waydroid.prop || echo "ro.com.google.clientidbase=android-google" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "ro.com.google.gmsversion" /var/lib/waydroid/waydroid.prop || echo "ro.com.google.gmsversion=12_202101" >> /var/lib/waydroid/waydroid.prop; \
    \
    # GMS device model properties \
    /usr/bin/grep -q "ro.vendor.extension_library" /var/lib/waydroid/waydroid.prop || echo "ro.vendor.extension_library=/vendor/lib/rfsa/adsp/libvpxe.so" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "ro.hardware" /var/lib/waydroid/waydroid.prop || echo "ro.hardware=ranchu" >> /var/lib/waydroid/waydroid.prop; \
    \
    # Build fingerprint for Play Store \
    /usr/bin/grep -q "ro.build.fingerprint" /var/lib/waydroid/waydroid.prop || echo "ro.build.fingerprint=google/sdk_google_phone_x86_64/generic_x86_64:12/S2B2.220216.003/7637154:user/release-keys" >> /var/lib/waydroid/waydroid.prop; \
    \
    # Security and permissions \
    /usr/bin/grep -q "ro.secure" /var/lib/waydroid/waydroid.prop || echo "ro.secure=1" >> /var/lib/waydroid/waydroid.prop; \
    /usr/bin/grep -q "ro.debuggable" /var/lib/waydroid/waydroid.prop || echo "ro.debuggable=0" >> /var/lib/waydroid/waydroid.prop; \
    \
    # GApps configuration \
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

systemctl enable waydroid-first-init.service || true

# Create watchdog script for automatic container freeze recovery
cat > /usr/bin/waydroid-watchdog << 'WATCHDOGEOF'
#!/bin/bash
# Waydroid container freeze watchdog - runs via timer to detect and recover frozen containers

WAYDROID_ROOT="/var/lib/waydroid"
LXC_PATH="$WAYDROID_ROOT/lxc"
WATCHDOG_LOG="/var/log/waydroid-watchdog.log"

{
  echo "[$(date)] Watchdog check started"
  
  # Check container state
  if lxc-info -P "$LXC_PATH" -n waydroid &>/dev/null; then
    STATE=$(lxc-info -P "$LXC_PATH" -n waydroid -sH 2>/dev/null | tr -d ' ')
    
    if [[ "$STATE" == "FROZEN" ]]; then
      echo "[$(date)] [CRITICAL] Container is FROZEN - auto-recovering..."
      
      # Attempt unfreeze
      if lxc-unfreeze -P "$LXC_PATH" -n waydroid 2>&1; then
        sleep 2
        NEW_STATE=$(lxc-info -P "$LXC_PATH" -n waydroid -sH 2>/dev/null | tr -d ' ')
        echo "[$(date)] Recovery successful. New state: $NEW_STATE"
        
        # Restart waydroid session if needed
        if ! waydroid status 2>/dev/null | grep -qi "running"; then
          echo "[$(date)] Restarting waydroid session..."
          waydroid session start 2>&1
        fi
      else
        echo "[$(date)] WARNING: Unfreeze command failed"
      fi
    else
      echo "[$(date)] Container state: $STATE (normal)"
    fi
  fi
  
  echo "[$(date)] Watchdog check complete"
  
} >> "$WATCHDOG_LOG" 2>&1
WATCHDOGEOF

chmod +x /usr/bin/waydroid-watchdog

# Create watchdog timer to check container every 5 minutes
cat > /usr/lib/systemd/system/waydroid-watchdog.service << 'EOF'
[Unit]
Description=Waydroid Container Watchdog
ConditionPathExists=/var/lib/waydroid/lxc/waydroid/config
After=waydroid-first-init.service

[Service]
Type=oneshot
ExecStart=/usr/bin/waydroid-watchdog
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/lib/systemd/system/waydroid-watchdog.timer << 'EOF'
[Unit]
Description=Waydroid Container Watchdog Timer
Requires=waydroid-watchdog.service

[Timer]
# Run every 5 minutes
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable waydroid-watchdog.timer || true

# Create enhanced helper script for waydroid status monitoring and diagnostics
cat > /usr/bin/waydroid-check << 'CHECKEOF'
#!/bin/bash

# Enhanced Waydroid diagnostic and recovery script
WAYDROID_ROOT="/var/lib/waydroid"
LXC_PATH="$WAYDROID_ROOT/lxc"
LOG_DIR="/var/log/waydroid"
mkdir -p "$LOG_DIR"
DIAG_LOG="$LOG_DIR/waydroid-diagnostics.log"

{
  echo "=== Waydroid Diagnostic Report: $(date) ==="
  
  # 1. Check container state
  echo -e "\n[1] Container State Check:"
  if lxc-info -P "$LXC_PATH" -n waydroid &>/dev/null; then
    CONTAINER_STATE=$(lxc-info -P "$LXC_PATH" -n waydroid -sH 2>/dev/null | tr -d ' ')
    echo "  Container exists: YES"
    echo "  State: $CONTAINER_STATE"
    
    if [[ "$CONTAINER_STATE" == "FROZEN" ]]; then
      echo "  [CRITICAL] Container is FROZEN - attempting recovery..."
      lxc-unfreeze -P "$LXC_PATH" -n waydroid 2>&1
      sleep 2
      NEW_STATE=$(lxc-info -P "$LXC_PATH" -n waydroid -sH 2>/dev/null | tr -d ' ')
      echo "  State after unfreeze: $NEW_STATE"
    fi
  else
    echo "  Container exists: NO"
  fi
  
  # 2. Check files
  echo -e "\n[2] Critical Files:"
  [[ -f "$WAYDROID_ROOT/images/system.img" ]] && echo "  system.img: ✓" || echo "  system.img: ✗"
  [[ -f "$WAYDROID_ROOT/images/vendor.img" ]] && echo "  vendor.img: ✓" || echo "  vendor.img: ✗"
  [[ -f "$WAYDROID_ROOT/lxc/waydroid/config" ]] && echo "  LXC config: ✓" || echo "  LXC config: ✗"
  [[ -f "$WAYDROID_ROOT/waydroid.prop" ]] && echo "  waydroid.prop: ✓" || echo "  waydroid.prop: ✗"
  [[ -f "$WAYDROID_ROOT/.initialized" ]] && echo "  Initialized flag: ✓" || echo "  Initialized flag: ✗"
  
  # 3. Session State
  echo -e "\n[3] Session State:"
  if waydroid status 2>/dev/null | head -5; then
    true
  else
    echo "  waydroid status: <error or session not active>"
  fi
  
  # 4. GMS/Google Play Services Check (safe - no shell access)
  echo -e "\n[4] Waydroid Properties:"
  if [[ -f "$WAYDROID_ROOT/waydroid.prop" ]]; then
    echo "  DNS Settings:"
    grep "^net.dns" "$WAYDROID_ROOT/waydroid.prop" | sed 's/^/    /'
    echo "  GAPPS Settings:"
    grep -E "^ro.waydroid|^persist.sys.usb" "$WAYDROID_ROOT/waydroid.prop" | head -5 | sed 's/^/    /'
  fi
  
  # 5. systemd service status
  echo -e "\n[5] Systemd Services:"
  systemctl is-active waydroid-container.service >/dev/null 2>&1 && echo "  waydroid-container: active" || echo "  waydroid-container: inactive"
  systemctl is-active waydroid-first-init.service >/dev/null 2>&1 && echo "  waydroid-first-init: active" || echo "  waydroid-first-init: inactive"
  
  # 6. Recent Errors
  echo -e "\n[6] Recent Journal Entries (errors/warnings):"
  if journalctl -u waydroid-container.service -n 20 --no-pager 2>/dev/null | grep -i "error\|warn\|fail"; then
    echo "  ^^ Errors found in waydroid-container logs"
  else
    echo "  No errors detected in recent logs"
  fi
  
  # 7. Init log status
  echo -e "\n[7] Initialization Log:"
  if [[ -f "/var/log/waydroid-init.log" ]]; then
    echo "  Last 10 lines of waydroid-init.log:"
    tail -10 "/var/log/waydroid-init.log" | sed 's/^/    /'
  else
    echo "  No waydroid-init.log found"
  fi
  
  echo -e "\n=== Diagnostic Complete ==="
  
} | tee -a "$DIAG_LOG"

# Show summary
echo -e "\nFull diagnostics saved to: $DIAG_LOG"
CHECKEOF

chmod +x /usr/bin/waydroid-check

# Create Play Store debugging and recovery script
cat > /usr/bin/waydroid-playstore-debug << 'DEBUGEOF'
#!/bin/bash
# Play Store debugging and recovery helper

WAYDROID_ROOT="/var/lib/waydroid"
DEBUG_LOG="/var/log/waydroid-playstore-debug.log"

{
  echo "=== Play Store Debugging Report: $(date) ==="
  
  echo -e "\n[1] Checking Waydroid properties for Play Store support..."
  if [[ -f "$WAYDROID_ROOT/waydroid.prop" ]]; then
    echo "  Found waydroid.prop, checking critical properties:"
    
    echo -e "\n  GMS Device Properties:"
    grep -E "ro.com.google|ro.build.fingerprint|ro.hardware" "$WAYDROID_ROOT/waydroid.prop" | while read line; do
      echo "    ✓ $line"
    done
    
    echo -e "\n  Network Properties:"
    grep "persist.waydroid.fake_wifi\|^net\." "$WAYDROID_ROOT/waydroid.prop" | head -5 | while read line; do
      echo "    ✓ $line"
    done
    
    echo -e "\n  Security Properties:"
    grep "ro.secure\|ro.debuggable" "$WAYDROID_ROOT/waydroid.prop" | while read line; do
      echo "    ✓ $line"
    done
  fi
  
  echo -e "\n[2] Session and Container Status:"
  SESSION_STATUS=$(waydroid status 2>/dev/null || echo "ERROR")
  if [[ "$SESSION_STATUS" != "ERROR" ]]; then
    echo "$SESSION_STATUS" | sed 's/^/  /'
  else
    echo "  WARNING: Unable to get session status"
  fi
  
  echo -e "\n[3] Service Status:"
  systemctl is-active waydroid-container >/dev/null 2>&1 && echo "  waydroid-container: active" || echo "  waydroid-container: inactive"
  
  echo -e "\n[4] Journal Analysis (last 30 lines, errors/warnings only):"
  journalctl -u waydroid-container.service -n 30 --no-pager 2>/dev/null | grep -i "error\|warn\|fail\|gms\|play" | head -10 | sed 's/^/  /' || echo "  No relevant entries found"
  
  echo -e "\n[5] Recommendations:"
  echo "  If Play Store doesn't appear:"
  echo "    1. Clear Play Store cache: waydroid shell pm clear com.android.vending"
  echo "    2. Wait 2-3 minutes for full boot (GMS downloads on first start)"
  echo "    3. Try opening Settings > Google > Manage Google Account > Recovery"
  echo ""
  echo "  If container freezes during diagnostics:"
  echo "    1. The watchdog will auto-recover in ~5 minutes"
  echo "    2. Manual recovery: lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid"
  echo "    3. Then restart: waydroid session stop && waydroid session start"
  
  echo -e "\n=== Debug Report Complete ==="
  
} | tee -a "$DEBUG_LOG"

echo -e "\nDebug log saved to: $DEBUG_LOG"
DEBUGEOF

chmod +x /usr/bin/waydroid-playstore-debug


# Full OS rebranding with DE detection
sed -i 's/^NAME=.*/NAME="NixoraOS"/' /etc/os-release
sed -i 's/^ID=.*/ID=nixoraos/' /etc/os-release
sed -i 's/^ID_LIKE=.*/ID_LIKE=fedora/' /etc/os-release
sed -i 's/^HOME_URL=.*/HOME_URL="https:\/\/nixoraos.example.com"/' /etc/os-release
sed -i 's/^SUPPORT_URL=.*/SUPPORT_URL="https:\/\/nixoraos.example.com\/support"/' /etc/os-release
sed -i 's/^BUG_REPORT_URL=.*/BUG_REPORT_URL="https:\/\/nixoraos.example.com\/bugs"/' /etc/os-release
sed -i 's/^VERSION=.*/VERSION="1.0"/' /etc/os-release

if [[ "$DESKTOP_FLAVOR" == "GNOME" ]]; then
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="NixoraOS GNOME"/' /etc/os-release
elif [[ "$DESKTOP_FLAVOR" == "KDE" ]]; then
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="NixoraOS KDE"/' /etc/os-release
else
  sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="NixoraOS"/' /etc/os-release
fi