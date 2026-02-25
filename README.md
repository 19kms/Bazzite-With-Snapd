# ⚠️ WARNING: Automatic or unexpected reboots may occur

We are actively investigating and working toward a permanent solution. Please save your work frequently and be aware that system reboots may happen without notice during updates or image switches.

If you want to turn off auto-updating until this is resolved, run:

	sudo systemctl disable --now bootc-fetch-apply-updates.timer

**Note:** With auto-updating disabled, you will need to update manually:

	sudo bootc upgrade
	sudo reboot
# Bazzite-With-Snapd

Custom Universal Blue image based on Bazzite, with:

- Snap support (`snapd`)
- Waydroid preinstalled
- Preinstalled GNOME extensions
- Dual image variants (`latest` and `nvidia`)

## Image Variants

- `ghcr.io/19kms/bazzite-with-snapd:latest`
	- Base: `ghcr.io/ublue-os/bazzite-gnome:stable`
	- Intended for non-NVIDIA systems (or users who prefer standard variant)

- `ghcr.io/19kms/bazzite-with-snapd:nvidia`
	- Base: `ghcr.io/ublue-os/bazzite-gnome-nvidia:stable`
	- Intended for NVIDIA systems

Both variants share the same custom layer from `build_files/build.sh`.

## What This Repo Changes

- Enables Snap runtime requirements (`snapd.socket`, `/snap` symlink)
- Installs/initializes Waydroid service
- Installs selected GNOME extensions system-wide
- Sets default enabled extension list via dconf

## Auto GPU Switching

The repo includes `scripts/switch-image-by-gpu.sh`, which can switch to `:nvidia` when NVIDIA hardware is detected.

Manual usage:

```bash
sudo /usr/bin/switch-image-by-gpu.sh 19kms/bazzite-with-snapd latest nvidia
sudo reboot
```

## Build and Publish

GitHub Actions in `.github/workflows/build.yml` builds and publishes both variants.

On push to `main`, images are published to:

- `ghcr.io/19kms/bazzite-with-snapd:latest`
- `ghcr.io/19kms/bazzite-with-snapd:nvidia`

## Switch to an Image

Switch to standard variant:

```bash
sudo bootc switch ghcr.io/19kms/bazzite-with-snapd:latest
sudo reboot
```

Switch to NVIDIA variant:

```bash
sudo bootc switch ghcr.io/19kms/bazzite-with-snapd:nvidia
sudo reboot
```

## Verify NVIDIA State

```bash
nvidia-smi
lsmod | grep nvidia
echo $XDG_SESSION_TYPE
```

## GNOME Extensions

Extension refs are defined in:

- `build_files/gnome-extension-refs.env`

The install logic in `build_files/build.sh` is resilient:

- Failed extension download does not fail the entire image build
- Schemas are compiled when present

## Common Troubleshooting

### `nvidia-smi` not working

1. Confirm you are actually booted into the expected image:

```bash
sudo bootc status | sed -n '/Booted image:/p;/Staged image:/p'
```

2. Switch explicitly to NVIDIA image and reboot:

```bash
sudo bootc switch ghcr.io/19kms/bazzite-with-snapd:nvidia
sudo reboot
```

### Switched image but booted image did not change

Run:

```bash
sudo bootc status | sed -n '/Booted image:/p;/Staged image:/p'
```

Check that `Staged image` is correct before reboot.

### GNOME extension schema errors

The image build compiles schemas for installed extensions. If needed on a live system:

```bash
glib-compile-schemas ~/.local/share/gnome-shell/extensions/<extension-id>/schemas
```

## Waydroid

Waydroid is preinstalled and initialized on first boot with Google Apps (GAPPS).

**Note:** The Google Play Store does not work on x86_64 Waydroid due to upstream limitations. Use Aurora Store (pre-installed) to download and install Android apps instead.

### Using Aurora Store

Aurora Store is an open-source alternative client for the Play Store, allowing you to download and update Android apps without a Google account. It is pre-installed in Waydroid. Open Aurora Store from the Waydroid app drawer to get started.

### First Boot Initialization

- Runs automatically via `waydroid-first-init.service` after reboot
- Fixes LXC architecture placeholder (`LXCARCH` → `x86_64`)
- Configures DNS (8.8.8.8, 8.8.4.4) for Google Play Store connectivity
- Logs detailed output to `/var/log/waydroid-init.log`

### Server Fallback

If the official GAPPS server (`ota.waydro.id`) is unavailable:
1. Automatically falls back to amstel-dev vanilla server (Android 13)
2. On vanilla fallback, GApps installation info is logged
3. You can manually install GApps later as needed

### Manual GApps Installation (if needed)

If using vanilla image without GAPPS, install GApps with BiTGApps:

```bash
# Download BiTGApps for Lineage 20 (Android 13)
# https://bitgapps.github.io/

# Extract and install:
waydroid session stop
cd /path/to/extracted/bitgapps
./install.sh /var/lib/waydroid/rootfs/system
waydroid session start
```

### Troubleshooting Waydroid

**Check initialization status:**
```bash
cat /var/log/waydroid-init.log
```

**Check container health:**
```bash
waydroid-check
```

**Manually verify DNS:**
```bash
sudo waydroid shell getprop net.dns1
```

Should return `8.8.8.8`. If empty, DNS wasn't applied - check `/var/log/waydroid-init.log`.

**Container frozen:**
```bash
sudo lxc-unfreeze -P /var/lib/waydroid/lxc -n waydroid
```

