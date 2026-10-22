#!/usr/bin/env bash
# 04-secrets.sh - create the age key and put its PUBLIC half in .sops.yaml.
# The private key stays in $AGE_KEY_FILE and must never enter git.
source "$(dirname "$0")/lib.sh"
need age-keygen sops

if [[ -f $AGE_KEY_FILE ]]; then
  log "age key exists: $AGE_KEY_FILE (not overwritten)"
else
  run mkdir -p "$(dirname "$AGE_KEY_FILE")"
  run age-keygen -o "$AGE_KEY_FILE"   # creates the file with mode 600
fi

if [[ -f $AGE_KEY_FILE ]]; then
  pub=$(age-keygen -y "$AGE_KEY_FILE")
  run sed -i "s|^\(\s*age: \).*|\1$pub|" "$REPO_DIR/.sops.yaml"
fi

warn "BACK UP $AGE_KEY_FILE now: cloud password manager + a copy on the drive."
warn "Lose it and every encrypted secret is unrecoverable. See docs/secrets.md."
