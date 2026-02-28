#!/usr/bin/env bash
set -e

# Enable RPM Fusion repositories (for NVIDIA drivers)
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install NVIDIA drivers and kernel modules
dnf install -y akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda

# Reboot or reload kernel modules if needed
echo "NVIDIA drivers installed. Please reboot or reload kernel modules."