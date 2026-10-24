#!/usr/bin/env bash
# install-plugins.sh - copy the vetted search plugins in plugins/ into the running qBittorrent pod.
# Re-run after a fresh install or a wiped config volume. Dry run unless APPLY=1.
# Plugins are Python code that runs inside the pod, so only files whose sha256 matches
# plugins/SHA256SUMS are installed. To add or update one: read it, then re-run `sha256sum` into that file.
set -euo pipefail
cd "$(dirname "$0")"
DEST=/config/qBittorrent/data/nova3/engines

(cd plugins && sha256sum -c SHA256SUMS)   # abort on any mismatch
for f in plugins/*.py; do
  if [[ ${APPLY:-0} == 1 ]]; then
    kubectl -n qbittorrent exec -i deploy/qbittorrent -- sh -c "cat > $DEST/$(basename "$f")" < "$f"
    echo "installed $(basename "$f")"
  else
    echo "would install $(basename "$f") (APPLY=1 to do it)"
  fi
done
