# Waydroid Troubleshooting & Deep Diagnostics Guide

This guide covers comprehensive troubleshooting for Waydroid issues in Bazzite-With-Snapd, focusing on Play Store functionality and container stability.

## Quick Status Check

```bash
# Run the enhanced diagnostic tool
waydroid-check

# Specifically debug Play Store issues
waydroid-playstore-debug
```

Both tools provide detailed diagnostics and save logs for analysis.

---

## Understanding the Three-Tier Support System

We've implemented automatic recovery mechanisms:

### Tier 1: Automatic Watchdog (Runs Every 5 Minutes)
- **What it does**: Automatically detects and unfreezes frozen containers
- **Log location**: `/var/log/waydroid-watchdog.log`
- **Status**: `systemctl status waydroid-watchdog.timer`
- **If container freezes**: Recovery happens automatically within ~5 minutes

### Tier 2: On-Demand Diagnostics
- **waydroid-check**: Full system diagnostics without container interaction
- **waydroid-playstore-debug**: Play Store-specific analysis
- **Both create detailed logs** in `/var/log/waydroid/`

### Tier 3: Manual Recovery
- For when you need immediate action

---

## Issue #1: Play Store Won't Open or Keeps Crashing

### Root Cause
Play Store requires proper device certification with two critical elements:
1. **GMS Device Properties** - Device model fingerprints
2. **Network Configuration** - Fake WiFi for connectivity simulation

### Diagnosis
```bash
# Check if properties were applied correctly
waydroid-playstore-debug

# Look for these in the output:
# - GMS Device Properties (ro.com.google.clientidbase, ro.build.fingerprint)
# - Network Properties (persist.waydroid.fake_wifi=true)
```

### Step-by-Step Fix

**Step 1: Verify Properties**
```bash
# These should all return values
grep "ro.build.fingerprint" /var/lib/waydroid/waydroid.prop
grep "persist.waydroid.fake_wifi" /var/lib/waydroid/waydroid.prop
grep "ro.com.google.clientidbase" /var/lib/waydroid/waydroid.prop
```

**Step 2: If Properties Missing**
Add them manually:
```bash
# Ensure fake WiFi is enabled
echo "persist.waydroid.fake_wifi=true" | sudo tee -a /var/lib/waydroid/waydroid.prop

# Add GMS fingerprint if missing
echo "ro.build.fingerprint=google/sdk_google_phone_x86_64/generic_x86_64:12/S2B2.220216.003/7637154:user/release-keys" | sudo tee -a /var/lib/waydroid/waydroid.prop

# Restart session
waydroid session stop
waydroid session start
```

**Step 3: Wait for GMS Initialization**
- First boot takes 2-3 minutes (GMS downloads ~500MB)
- Watch the Android UI, you'll see "Network" and "Google" services starting
- Play Store appears after GMS fully initializes

**Step 4: If Still Not Working**
```bash
# Clear Play Store cache (safe - won't delete data)
sudo waydroid shell pm clear com.android.vending

# Then close and reopen Play Store
# Or access Settings > Apps > Google Play Store > Storage > Clear Cache
```

### Advanced: Force Device Registration
```bash
# Open Android Settings via Waydroid UI:
# Settings > Accounts & sync > Google > Add account
# Complete the flow - this registers device with Google

# Then try Play Store again
```

---

## Issue #2: Container Freezes When Running Diagnostics

### Root Cause
Waydroid's LXC container occasionally freezes when receiving shell commands. The watchdog auto-recovers, but you can force manual recovery.

### Immediate Recovery
```bash
# If container is frozen and you need immediate action:
sudo lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid

# Wait 5 seconds, then restart session
sleep 5
waydroid session stop
waydroid session start
```

### Why It Happens
- System load spikes cause LXC to freeze container for stability
- Certain shell commands trigger container suspend
- **This is normal behavior** - watchdog auto-recovers in ~5 minutes

### Prevention
- Don't run multiple `waydroid shell` commands rapidly
- Wait 10+ seconds between diagnostics
- Use `waydroid-check` and `waydroid-playstore-debug` instead (they don't freeze containers)

---

## Issue #3: Session Status Reports Wrong State

### What's Happening
`waydroid status` sometimes reports STOPPED when running, or vice versa. This is a Waydroid reporting bug, not a real issue.

### Check Real State
```bash
# This is the true indicator:
lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH

# Should return one of: RUNNING, STOPPED, FROZEN, THAWED
```

### If Status Command Lies
```bash
# Force session restart
sudo waydroid session stop  # Ignore if it says already stopped
sleep 3
sudo waydroid session start  # Ignore if it says already running

# Verify real state
lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH
```

---

## GMS/Google Play Services Debugging

### Check GMS Status (Without Shell Access)
```bash
# View GMS configuration properties
grep -E "ro.com.google|ro.build|ro.secure" /var/lib/waydroid/waydroid.prop

# Expected output should include:
# ro.com.google.clientidbase=android-google
# ro.build.fingerprint=google/sdk_google_phone_x86_64/...
# ro.secure=1
# ro.debuggable=0
```

### If GMS Downloaded
```bash
# Check system partition size (GMS adds ~500MB)
du -h /var/lib/waydroid/images/system.img

# Should be >1GB if GMS included
```

### GMS Download Logs
```bash
# During first boot, GMS downloads show here:
tail -f /var/log/waydroid-init.log | grep -i "gapps\|download\|success"
```

---

## Complete Recovery Procedure

If everything is broken and you need a clean slate:

### Full Reset (WARNING: Deletes all Android data)
```bash
# Stop Waydroid
waydroid session stop

# Backup if needed
sudo cp -r /var/lib/waydroid /var/lib/waydroid.backup

# Remove everything
sudo rm -rf /var/lib/waydroid/*
sudo rm -f /var/lib/waydroid/.initialized

# On next boot, waydroid-first-init service re-initializes
# Or manually trigger:
sudo bash -c 'rm /var/lib/waydroid/.initialized && systemctl restart waydroid-first-init'
```

### Partial Reset (Keep data, fresh GMS)
```bash
# Keep data directories but reset system images
waydroid session stop
sudo rm /var/lib/waydroid/.initialized
sudo rm /var/lib/waydroid/images/*.img
sudo rm -rf /var/lib/waydroid/lxc/waydroid

# Re-initialize
systemctl restart waydroid-first-init
```

---

## Extracting Detailed Logs

### For Support/Debugging

```bash
# Complete Waydroid logs
sudo bash -c 'cat > /tmp/waydroid-support.txt << EOF
=== VERSION ===
$(waydroid --version 2>/dev/null)

=== INITIALIZATION LOG ===
$(tail -100 /var/log/waydroid-init.log 2>/dev/null)

=== DIAGNOSTICS ===
$(waydroid-check)

=== PLAYSTORE DEBUG ===
$(waydroid-playstore-debug)

=== PROPERTIES ===
$(grep -E "^(ro\.|persist\.)" /var/lib/waydroid/waydroid.prop 2>/dev/null | head -50)

=== JOURNAL ERRORS ===
$(journalctl -u waydroid-container.service -n 30 --no-pager 2>/dev/null)

=== WATCHDOG LOG ===
$(tail -50 /var/log/waydroid-watchdog.log 2>/dev/null)
EOF
cat /tmp/waydroid-support.txt'
```

---

## Key Properties Explained

These are set during first boot to enable Play Store:

| Property | Value | Purpose |
|----------|-------|---------|
| `ro.com.google.clientidbase` | `android-google` | Identifies device to Google Services |
| `ro.build.fingerprint` | `google/sdk_google_phone_x86_64/...` | Device model fingerprint for certification |
| `ro.secure` | `1` | Security flag required for GMS |
| `ro.debuggable` | `0` | Disables debug mode for production GMS |
| `persist.waydroid.fake_wifi` | `true` | Enables WiFi simulation for connectivity |
| `net.dns1` | `8.8.8.8` | Primary DNS for network access |
| `net.dns2` | `8.8.4.4` | Secondary DNS for reliability |

---

## When to Reset vs. Recover

| Symptom | Action |
|---------|--------|
| Play Store crashes on open | Try [Fix #1: Set Properties](#step-by-step-fix) first |
| Container frozen for >10 min | Manual unfreeze + restart |
| Status reports wrong state | Run `waydroid session stop && waydroid session start` |
| Downloaded GMS but won't work | Clear Play Store cache, wait 2 min, try again |
| Multiple failed boot attempts | Full reset with `systemctl restart waydroid-first-init` |
| Data corruption suspected | Partial reset (keeps app data) |

---

## Testing Workflow

### Before Each Test Session
```bash
# 1. Check initial state
waydroid-check

# 2. Start session if needed
waydroid session start

# 3. Wait 30 seconds for boot
sleep 30

# 4. Run diagnostics
waydroid-playstore-debug
```

### During a Test
- Open Waydroid launcher from grid
- Navigate to Play Store
- Observe behavior
- If freezes: watchdog recovers in ~5 min
- If works: Note properties that succeeded

### After a Test
```bash
# Save logs for analysis
cp /var/log/waydroid-diagnostics.log ~/Test_Run_$(date +%s).log
cp /var/log/waydroid-playstore-debug.log ~/Debug_Run_$(date +%s).log
```

---

## Advanced: Monitoring Real-Time

```bash
# Watch watchdog in action
tail -f /var/log/waydroid-watchdog.log

# Monitor container state continuously
watch -n 1 'lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH'

# Follow GMS initialization
tail -f /var/log/waydroid-init.log

# Track Play Store specifics
grep -i "play\|store\|gms" /var/log/waydroid-init.log
```

---

## Quick Reference: Common Commands

```bash
# Status and diagnostics
waydroid-check                          # Full diagnostics
waydroid-playstore-debug                # Play Store focus
waydroid status                         # Quick status (may be inaccurate)

# Session control
waydroid session start                  # Start container
waydroid session stop                   # Stop container
lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid  # Manual unfreeze

# Property inspection
cat /var/lib/waydroid/waydroid.prop    # All properties
grep "ro.build.fingerprint" /var/lib/waydroid/waydroid.prop  # Device fingerprint

# Log inspection
tail -f /var/log/waydroid-init.log     # Initialization progress
tail -f /var/log/waydroid-watchdog.log # Watchdog activity
ls -lh /var/log/waydroid/              # All diagnostic logs
```

---

## Known Limitations

1. **Play Store May Take 2-3 Minutes on First Boot**
   - GMS downloads prerequisites during initialization
   - This is expected and normal

2. **WiFi Simulation is Fake**
   - Android thinks it has WiFi but uses host network
   - Some strict apps might detect this
   - Won't affect most applications

3. **Container May Occasionally Freeze**
   - Waydroid/LXC behavior
   - Watchdog auto-recovers within 5 minutes
   - Manual recovery available anytime

4. **Device Certification Incomplete**
   - Some banking/payment apps may not work
   - Play Store itself works fine
   - Regular app sideloading always works

---

## Still Having Issues?

1. **Run full diagnostics**: `waydroid-check && waydroid-playstore-debug`
2. **Check logs**: `tail -100 /var/log/waydroid-init.log`
3. **Wait longer**: GMS initialization can take 5+ minutes
4. **Try recovery**: `waydroid session stop && sleep 5 && waydroid session start`
5. **Full reset**: Use the procedure above if all else fails

