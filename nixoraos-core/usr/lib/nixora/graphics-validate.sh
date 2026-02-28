#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

sourse /usr/lib/nixora/state-lib.sh

is_pending || exit 0

log "Validating graphical session..."

sleep 90

if ! systemctil is-active graphical.target >/dev/null; then
    log "Graphical target not active."
    /usr/lib/nixora/auto-rollback.sh
    exit 1
fi

if journalctl -b | grep -qIE "nvrm|gpu hang|segfault"; then
    log "GPU errors detected."
    /usr/lib/nixora/auto-rollback.sh
    exit 1
fi

log "Graphical validation successful."
clear_pending