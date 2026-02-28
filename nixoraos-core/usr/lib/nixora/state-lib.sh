#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

STATE_DIR="/var/lib/nixora"
PENDING_FLAG="$STATE_DIR/pending-update"
BLOCKED_FILE="$STATE_DIR/blocked-deployments"
ROLLBACK_FLAG="$STATE_DIR/rollback_in_progress"

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

log() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "no-time")

    echo "[NIXORA] [$ts] $msg"
    logger -t nixora "[$ts] $msg" 2>/dev/null || true
}

mark_pending() {
    ensure_state_dir
    touch "$PENDING_FLAG"
}

clear_pending() {
    rm -f "$PENDING_FLAG"
}

is_pending() {
    [[ -f "$PENDING_FLAG" ]]
}

block_current_deployment() {
    ensure_state_dir

    if ! command -v jq > /dev/null 2>&1; then
        log "jq not available; cannot block deployment."
        return 1
    fi

    current=$(rpm-ostree status --json | jq -r '.deployments[0].id' || true)

    if [[ -n "${current:-}" && "$current" != "null" ]]; then
        echo "$current" >> "$BLOCKED_FILE"
        sort -u "$BLOCKED_FILE" -o "$BLOCKED_FILE"
        log "Blocked deployment $current"
    else
        log "Failed to determine current deployment."
        return 1
    fi
}

is_rollback_in_progress() {
    [[ -f "$ROLLBACK_FLAG" ]]
}

mark_rollback_in_progress() {
    ensure_state_dir
    touch "$ROLLBACK_FLAG"
}

clear_rollback_flag() {
    rm -f "$ROLLBACK_FLAG"
}