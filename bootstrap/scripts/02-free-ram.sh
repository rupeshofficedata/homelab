#!/usr/bin/env bash
# 02-free-ram.sh - stop Docker containers to free memory for k3s.
# Only containers whose name matches STOP_CONTAINERS_REGEX (in config.env) are stopped.
# Their names are saved, so you can start them again later.
# Skip this script if you have nothing to stop.
source "$(dirname "$0")/lib.sh"
need docker

SAVED_LIST="$HOME/.cache/homelab/stopped-containers.txt"

[[ -n $STOP_CONTAINERS_REGEX ]] || { log "STOP_CONTAINERS_REGEX is empty in config.env: nothing to stop"; exit 0; }

mapfile -t names < <(docker ps --format '{{.Names}}' | grep -E "$STOP_CONTAINERS_REGEX" || true)
(( ${#names[@]} )) || { log "no running container matches: nothing to stop"; exit 0; }

log "will stop: ${names[*]}"
if [[ $APPLY == 1 ]]; then
  mkdir -p "$(dirname "$SAVED_LIST")"
  printf '%s\n' "${names[@]}" > "$SAVED_LIST"
fi
run docker stop "${names[@]}"
log "start them again later with: xargs docker start < $SAVED_LIST"
