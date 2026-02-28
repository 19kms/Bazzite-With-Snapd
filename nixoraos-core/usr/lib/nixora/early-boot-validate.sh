#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source /usr/lib/nixora/state-lib.sh

is_pending || exit 0

log "Running early boot validation..."

if lspci | grep -qi nvidia; then
    log "NVIDIA hardware detected."

    if ! lsmod | grep -q '^nvidia\b'; then
        log "NVIDIA kernel module not loaded."
        /usr/lib/nixora/auto-rollback.sh || true
        exit 1
    fi
fi

log "Early boot validation passed."

# --- SUCCESS CLEANUP ---
clear_pending
clear_rollback_flag

log "Update marked successful."

exit 0
