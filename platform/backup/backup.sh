#!/usr/bin/env bash
# backup.sh - nightly Immich backup to the external drive with restic.
# Installed to /usr/local/lib/homelab/ and run as root by homelab-backup.service.
# Config comes from /etc/homelab/backup.env (rendered by install.sh).
set -euo pipefail
source /etc/homelab/backup.env   # REPO PASSWORD_FILE KUBECONFIG DATA_GLOB VW_GLOB NC_GLOB NC_DATA MOUNT STATE_DIR
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

# 3b. Vaultwarden. The SQLite file is live, so ask the app for a consistent copy
#     (/data/db_*.sqlite3) first; restic then picks it up with the rest of /data.
#     Skipped until the app exists.
vw=$(compgen -G "$VW_GLOB" | head -1) || true
if [[ -n $vw ]]; then
  kubectl -n vaultwarden exec deploy/vaultwarden -- /vaultwarden backup
  restic backup "$vw" --tag vaultwarden --host homelab
  restic forget --host homelab --tag vaultwarden --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
fi

# 3c. Nextcloud. Maintenance mode freezes writes so the DB dump and the files agree;
#     the trap switches it back on-line even if a step fails. Skipped until the app exists.
nc=$(compgen -G "$NC_GLOB" | head -1) || true
if [[ -n $nc ]]; then
  occ() { kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- su -s /bin/sh www-data -c "php occ $*"; }
  trap 'occ maintenance:mode --off >/dev/null 2>&1 || true; rm -rf "$dump"' EXIT
  occ maintenance:mode --on
  kubectl -n nextcloud exec nextcloud-postgres-0 -- \
    sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$dump/nextcloud.pgdump"
  [[ -s $dump/nextcloud.pgdump ]] || { echo "empty Nextcloud DB dump" >&2; exit 1; }
  restic backup "$nc" "$NC_DATA" "$dump/nextcloud.pgdump" --tag nextcloud --host homelab
  occ maintenance:mode --off
  restic forget --host homelab --tag nextcloud --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
fi

# 4. Retention, then a weekly partial integrity check (5% of data, Sundays).
restic forget --host homelab --tag immich --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
[[ $(date +%u) != 7 ]] || restic check --read-data-subset=5%

# 5. Success stamp for monitoring (Phase 1b alerts on its age).
# The .prom file is read by node-exporter's textfile collector (Phase 1b alert BackupStale).
mkdir -p "$STATE_DIR"
now=$(date +%s)
echo "$now" > "$STATE_DIR/last-backup-success"
echo "homelab_backup_last_success_timestamp_seconds $now" > "$STATE_DIR/homelab_backup.prom.tmp"
mv "$STATE_DIR/homelab_backup.prom.tmp" "$STATE_DIR/homelab_backup.prom"
