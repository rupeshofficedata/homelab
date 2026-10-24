#!/usr/bin/env bash
# install-plugins.sh - copy the vetted search plugins in plugins/ into the running qBittorrent pod.
# Re-run after a fresh install or a wiped config volume. Dry run unless APPLY=1.
# Plugins are Python code that runs inside the pod, so ONLY files listed in plugins/SHA256SUMS
# are installed, and each is hashed and sent from the same private copy (no swap between check and use).
# To add or update one: read it, then regenerate plugins/SHA256SUMS with `sha256sum`.
set -euo pipefail
cd "$(dirname "$0")"
DEST=/config/qBittorrent/data/nova3/engines
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

while read -r sum name; do
  name=${name#\*}
  [[ $name =~ ^[A-Za-z0-9_]+\.py$ ]] || { echo "bad name in SHA256SUMS: $name" >&2; exit 1; }
  cp "plugins/$name" "$tmp/$name"
  echo "$sum  $tmp/$name" | sha256sum -c --quiet - || { echo "checksum mismatch: $name" >&2; exit 1; }
  if [[ ${APPLY:-0} == 1 ]]; then
    kubectl -n qbittorrent exec -i deploy/qbittorrent -- sh -c "cat > $DEST/$name" < "$tmp/$name"
    echo "installed $name"
  else
    echo "would install $name (APPLY=1 to do it)"
  fi
done < plugins/SHA256SUMS
