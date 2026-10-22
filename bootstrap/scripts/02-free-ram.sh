#!/usr/bin/env bash
# 02-free-ram.sh - stop the kind clusters and Jenkins to free RAM for k3s.
# Only containers whose name matches STOP_REGEX (config.env) are stopped.
# Their names are saved so they can be started again later.
source "$(dirname "$0")/lib.sh"
need docker

STATE="$HOME/.cache/homelab/stopped.txt"

mapfile -t names < <(docker ps --format '{{.Names}}' | grep -E "$STOP_REGEX" || true)
(( ${#names[@]} )) || { log "nothing to stop"; exit 0; }

log "will stop: ${names[*]}"
if [[ $APPLY == 1 ]]; then
  mkdir -p "$(dirname "$STATE")"
  printf '%s\n' "${names[@]}" > "$STATE"
fi
run docker stop "${names[@]}"
log "restart later with: xargs docker start < $STATE"
