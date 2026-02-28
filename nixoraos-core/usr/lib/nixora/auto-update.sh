#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source /usr/lib/nixora/state-lib.sh

log "Starting automatic update..."

if ! /usr/lib/nixora/preflight-check.sh; then
    log "Preflight check failed. Update aborted."
    exit 0
fi

log "Preflight check passed."

if rpm-ostree upgrade --stage; then
    mark_pending
    log "Update staged successfully. Pending reboot."
else
    log "rpm-ostree upgrade failed."
    exit 1
fi