#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1


# Install snapd for snap package support
dnf5 install -y snapd

# Create snapd socket directory (required for snap to function properly)
mkdir -p /var/lib/snapd

# Install GNOME desktop environment instead of KDE
dnf5 install -y gnome-desktop

# Optionally, remove KDE if present (uncomment if desired)
# dnf5 remove -y @kde-desktop

# Install and initialize waydroid (Android container)
dnf5 install -y waydroid
# Enable waydroid service
systemctl enable waydroid-container



# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging


#### Example for enabling a System Unit File

## Commented out to test boot reliability
# systemctl enable snapd.socket
# systemctl enable snapd.apparmor.service
# systemctl enable podman.socket

# Remove the "short leash" restrictions to allow unrestricted dnf/package installation
# This removes polkit rules that prevent interactive package installation
rm -f /etc/polkit-1/rules.d/*package* /etc/polkit-1/rules.d/*rpm*
