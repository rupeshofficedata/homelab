#!/usr/bin/env bash
# 04-secrets.sh - create the age key that locks and unlocks the secrets.
# The PUBLIC half (it only locks) goes into .sops.yaml and into git.
# The PRIVATE half stays in $AGE_KEY_FILE. It must never go into git.
source "$(dirname "$0")/lib.sh"
need age-keygen sops

if [[ -f $AGE_KEY_FILE ]]; then
  log "age key already exists: $AGE_KEY_FILE (not replaced)"
else
  run mkdir -p "$(dirname "$AGE_KEY_FILE")"
  run age-keygen -o "$AGE_KEY_FILE"   # also creates the file with owner-only permissions
fi

# Copy the public key into .sops.yaml.
if [[ -f $AGE_KEY_FILE ]]; then
  public_key=$(age-keygen -y "$AGE_KEY_FILE")
  run sed -i "s|^\(\s*age: \).*|\1$public_key|" "$REPO_DIR/.sops.yaml"
fi

warn "Back up $AGE_KEY_FILE now: a password manager, plus a copy on the backup drive."
warn "If you lose it, every encrypted secret is lost. See docs/secrets.md."
