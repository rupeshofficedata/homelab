#!/usr/bin/env bash
# lib.sh - shared helpers for the bootstrap scripts. Source it; do not run it.
#
# Safety model: every script is a DRY RUN unless APPLY=1 is set. Mutating
# commands go through run(), which prints the command and executes it only
# when APPLY=1. Read-only commands may run directly.
set -euo pipefail

BOOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # .../bootstrap
REPO_DIR=$(dirname "$BOOT_DIR")                             # repo root
# shellcheck source=../config.env
source "$BOOT_DIR/config.env"

: "${APPLY:=0}"

log()  { printf '\033[1;34m[homelab]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# need CMD...: abort if a required command is missing.
need() { local c; for c in "$@"; do command -v "$c" >/dev/null || die "missing command: $c"; done; }

# run CMD...: show the command; execute only with APPLY=1.
run() {
  printf '  $ %s\n' "$*"
  if [[ $APPLY == 1 ]]; then "$@"; fi
}

[[ $APPLY == 1 || ${READONLY:-0} == 1 ]] || log "DRY RUN - nothing changes. Re-run with APPLY=1 to apply."
