#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source /usr/lib/nixora/state-lib.sh

is_pending || exit 0

log "Running GPU health check..."

if ! lspci | grep -qi nvidia; then
    log "No NVIDIA GPU detected. Skipping."
    clear_pending
    clear_rollback_flag
    exit 0
fi

log "NVIDIA GPU detected."

FAILED=0
REASON=""

if ! lsmod | grep -q '^nvidia'; then
    FAILED=1
    REASON="NVIDIA kernel module not loaded."
fi

if [[ $FAILED -eq 0 ]] && ! ls /dev/dri/card* >/dev/null 2>&1; then
    FAILED=1
    REASON="No DRM devices found."
fi

if [[ $FAILED -eq 0 ]] && command -v nvidia-smi >/dev/null 2>&1; then
    if ! nvidia-smi >/dev/null 2>&1; then
        FAILED=1
        REASON="nvidia-smi failed."
    fi
fi

if [[ $FAILED -eq 0 ]]; then
    log "GPU health check passed."
    clear_pending
    clear_rollback_flag
    log "Update marked successful."
    exit 0
fi

log "GPU health check failed: $REASON"

if [[ -n "${DISPLAY:-}" ]] && command -v zenity >/dev/null 2>&1; then
    if zenity --question \
        --title="NixoraOS Update Issue Detected" \
        --width=400 \
        --text="GPU problem detected after update:\n\n$REASON\n\nDo you want to roll back to the previous version and reboot now?"; then
        clear_pending
        clear_rollback_flag
        log "User approved rollback."
        /usr/lib/nixora/auto-rollback.sh
    else
        log "User declined rollback."
        clear_pending
        clear_rollback_flag
    fi
else
    log "No graphical session available. Skipping user prompt."
fi

exit 0