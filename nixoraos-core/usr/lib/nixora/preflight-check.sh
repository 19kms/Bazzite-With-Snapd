#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source /usr/lib/nixora/state-lib.sh

log "Running preflight compatibility checks..."

if lspci | grep -qi nvidia; then
    log "NVIDIA GPU detected."

    if ! command -v modinfo >/dev/null 2>&1; then
        log "modinfo not available."
        exit 1
    fi

    DRIVER_VERSION=$(modinfo nvidia 2>/dev/null | awk '/^version:/ {print $2}' || true)

    if [[ -z "${DRIVER_VERSION:-}" ]]; then
        log "Unable to determine NVIDIA driver version."
        exit 1
    fi

    log "Driver version: $DRIVER_VERSION"

    # Example kernel safety rule (temporary policy guard)
    if rpm-ostree upgrade --preview 2>/dev/null | grep -q "kernel-7\."; then
        log "Kernel 7.x not validated for NVIDIA"
        exit 1
    fi
fi

log "Preflight checks passed."
exit 0