#!/usr/bin/env bash
# install-plugins.sh - copy the search plugins from plugins/ into the running qBittorrent pod.
# Run it again only after a fresh install or a wiped config volume.
# Preview by default. Use APPLY=1 to do it.
#
# SAFETY: plugins are Python code that runs inside the pod. So only the files
# listed in plugins/SHA256SUMS are installed, and each one must match its checksum.
# To add or update a plugin: read the code, then update plugins/SHA256SUMS with `sha256sum`.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../../bootstrap/scripts/lib.sh"
need kubectl sha256sum

DEST=/config/qBittorrent/data/nova3/engines   # where qBittorrent looks for plugins

# Work on a private copy, so a file cannot change between the check and the install.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

while read -r checksum name; do
  name=${name#\*}
  [[ $name =~ ^[A-Za-z0-9_]+\.py$ ]] || die "bad file name in SHA256SUMS: $name"

  cp "$HERE/plugins/$name" "$work/$name"
  echo "$checksum  $work/$name" | sha256sum -c --quiet - || die "checksum does not match: $name"

  if [[ $APPLY == 1 ]]; then
    kubectl -n qbittorrent exec -i deploy/qbittorrent -- sh -c "cat > $DEST/$name" < "$work/$name"
    log "installed $name"
  else
    log "would install $name"
  fi
done < "$HERE/plugins/SHA256SUMS"
