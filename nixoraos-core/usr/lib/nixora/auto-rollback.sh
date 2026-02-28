#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source /usr/lib/nixora/state-lib.sh

log "Rollback requested."

# Prevent rollback loops
if is_rollback_in_progress; then
    log "Rollback already in progress. Aborting to prevent loop."
    exit 1

fi

mark_rollback_in_progress

log "Rolling back to previous deployment..."

if ! rpm-ostree rollback; then
    log "Rollback failed."
    clear_rollback_flag
    exit 1
fi

log "Rollback staged successfully. Rebooting..."
reboot