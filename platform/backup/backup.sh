#!/usr/bin/env bash
# backup.sh - nightly Immich backup to the external drive with restic.
# Installed to /usr/local/lib/homelab/ and run as root by homelab-backup.service.
# Config comes from /etc/homelab/backup.env (rendered by install.sh).
set -euo pipefail
source /etc/homelab/backup.env   # REPO PASSWORD_FILE KUBECONFIG DATA_GLOB MOUNT STATE_DIR
export RESTIC_REPOSITORY=$REPO RESTIC_PASSWORD_FILE=$PASSWORD_FILE KUBECONFIG
export RESTIC_CACHE_DIR=${CACHE_DIRECTORY:-/var/cache/restic}

# 1. Drive guard. Listing the path triggers the automount. The repo `config`
#    file only exists on the real drive; the empty immutable mountpoint on the
#    SSD fails this test, so a missing drive can never fill the SSD.
ls "$MOUNT" >/dev/null 2>&1 || true
[[ -f $REPO/config ]] || { echo "backup repo not reachable at $REPO (drive unplugged?)" >&2; exit 1; }

# 2. Database dump. Safer than copying live Postgres files.
dump=$(mktemp -d -p /var/tmp); trap 'rm -rf "$dump"' EXIT
kubectl -n immich exec immich-postgres-0 -- \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$dump/immich.pgdump"
[[ -s $dump/immich.pgdump ]] || { echo "empty DB dump" >&2; exit 1; }

# 3. Library + dump -> one snapshot. Fixed --host keeps retention grouping stable.
lib=$(compgen -G "$DATA_GLOB" | head -1) || true
[[ -n $lib ]] || { echo "library dir not found: $DATA_GLOB" >&2; exit 1; }
restic backup "$lib" "$dump" --tag immich --host homelab

# 4. Retention, then a weekly partial integrity check (5% of data, Sundays).
restic forget --host homelab --tag immich --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
[[ $(date +%u) != 7 ]] || restic check --read-data-subset=5%

# 5. Success stamp for monitoring (Phase 1b alerts on its age).
mkdir -p "$STATE_DIR" && date +%s > "$STATE_DIR/last-backup-success"
