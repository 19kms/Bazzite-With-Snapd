#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [ghcr-owner/image-name] [standard-tag] [nvidia-tag]"
  echo "Example: $0 NixoraOS/nixoraos latest nvidia"
}

standard_tag="${2:-latest}"
nvidia_tag="${3:-nvidia}"

has_nvidia_gpu() {
  if compgen -G '/sys/class/drm/card*/device/vendor' > /dev/null; then
    if grep -qi '^0x10de$' /sys/class/drm/card*/device/vendor 2>/dev/null; then
      return 0
    fi
  fi

  if command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -Eiq 'VGA|3D|Display' && lspci -nn | grep -iq '10de|nvidia'; then
      return 0
    fi
  fi

  return 1
}

if [[ $# -ge 1 ]]; then
  base_ref="ghcr.io/$1"
  current_tag=""
else
  if ! command -v bootc >/dev/null 2>&1; then
    usage
    echo "bootc is not available and no image was provided."
    exit 1
  fi

  booted_ref="$(bootc status | awk -F': ' '/Booted image:/ {print $2; exit}')"
  if [[ -z "$booted_ref" ]]; then
    echo "Unable to determine current booted image from bootc status."
    exit 1
  fi

  booted_ref="${booted_ref%@*}"
  if [[ "$booted_ref" =~ :[^/]+$ ]]; then
    base_ref="${booted_ref%:*}"
    current_tag="${booted_ref##*:}"
  else
    base_ref="$booted_ref"
    current_tag="latest"
  fi
fi

selected_tag="$standard_tag"
if has_nvidia_gpu; then
  selected_tag="$nvidia_tag"
fi

target_ref="${base_ref}:${selected_tag}"
if [[ -n "${current_tag:-}" && "$current_tag" == "$selected_tag" ]]; then
  echo "Already on the desired tag (${selected_tag}); no switch required."
  exit 0
fi

echo "Switching to: ${target_ref}"
if [[ "${EUID}" -eq 0 ]]; then
  bootc switch "${target_ref}"
else
  sudo bootc switch "${target_ref}"
fi

echo "Switch queued. Please reboot manually to apply the new image. (No automatic reboot will occur.)"
