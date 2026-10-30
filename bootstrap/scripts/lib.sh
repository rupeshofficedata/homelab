#!/usr/bin/env bash
# lib.sh - helper functions shared by every script in this repo.
# Other scripts load it with `source`. You do not run it yourself.
#
# SAFETY: every script is a DRY RUN by default. It only prints what it would do.
# Set APPLY=1 to make it really do it:
#     ./bootstrap/scripts/03-storage.sh           # preview
#     APPLY=1 ./bootstrap/scripts/03-storage.sh   # do it
#
# Functions:
#   log / warn / die        print a message (die also stops the script)
#   need CMD...             stop if a program is not installed
#   run CMD...              print a command, and run it only when APPLY=1
#   random_password         print a random password
#   tailnet_name            print this machine's Tailscale name
#   create_namespace NAME   create a Kubernetes namespace if it is missing
#   create_secret_file FILE FUNCTION
#                           encrypt FUNCTION's output into FILE, only if FILE is missing
#   apply_secret FILE       decrypt FILE and send it to the cluster

set -euo pipefail

# --- Where things are ---------------------------------------------------------
BOOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # the bootstrap/ folder
REPO_DIR=$(dirname "$BOOT_DIR")                             # the top of the repo

source "$BOOT_DIR/config.env"
# Optional per-machine overrides (ignored by git).
if [[ -f $BOOT_DIR/config.local.env ]]; then source "$BOOT_DIR/config.local.env"; fi

# kubectl and sops find their settings through these two variables.
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE

# All scripts work from the top of the repo, so paths like secrets/x.enc.yaml are simple.
cd "$REPO_DIR"

: "${APPLY:=0}"   # 0 = preview only (default), 1 = really do it

# --- Messages -------------------------------------------------------------------
log()  { printf '\033[1;34m[homelab]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Checks and commands --------------------------------------------------------
# need CMD...  Stop with a clear message if a program is missing.
need() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || die "missing program: $cmd"
  done
}

# run CMD...  Show the command. Run it only when APPLY=1.
# Use it for every command that changes something.
run() {
  printf '  $ %s\n' "$*"
  if [[ $APPLY == 1 ]]; then "$@"; fi
}

# --- Secrets and Kubernetes helpers -----------------------------------------------
# random_password  Print a random 48-character password (letters a-f and digits).
random_password() { openssl rand -hex 24; }

# tailnet_name  Print this machine's Tailscale name, e.g. mypc.tail1234.ts.net
tailnet_name() {
  tailscale status --json | python3 -c "import json,sys; print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))"
}

# create_namespace NAME  Create the namespace unless it already exists.
create_namespace() {
  printf '  $ create namespace %s (if missing)\n' "$1"
  if [[ $APPLY == 1 ]]; then
    kubectl create namespace "$1" --dry-run=client -o yaml | kubectl apply -f -
  fi
}

# create_secret_file FILE FUNCTION
#   If FILE does not exist yet, run FUNCTION (it prints a Kubernetes Secret as YAML),
#   encrypt that output with SOPS and save it as FILE. The plain text never touches the disk.
#   If FILE exists, nothing happens, so passwords are only generated once.
create_secret_file() {
  local file=$1 make_yaml=$2
  [[ -f $file ]] && return 0
  log "creating $file"
  if [[ $APPLY == 1 ]]; then
    "$make_yaml" | sops -e --filename-override "$file" --input-type yaml --output-type yaml /dev/stdin > "$file.tmp" \
      || { rm -f "$file.tmp"; die "could not encrypt $file"; }
    mv "$file.tmp" "$file"
    log "created $file (encrypted). Commit it to git."
  fi
}

# apply_secret FILE  Decrypt FILE in memory and send it straight to the cluster.
apply_secret() {
  log "applying $1 to the cluster (decrypted in memory only)"
  if [[ $APPLY == 1 ]]; then sops -d "$1" | kubectl apply -f -; fi
}

# Remind the user that nothing happened yet.
# READONLY=1 (set by scripts that never change anything) hides this message.
if [[ $APPLY != 1 && ${READONLY:-0} != 1 ]]; then
  log "DRY RUN: nothing changes. Run again with APPLY=1 to apply."
fi
