#!/usr/bin/env bash
# backup.sh - the nightly backup. It copies Immich, Vaultwarden and Nextcloud to the
# external drive with restic (an encrypted backup tool).
# install.sh copies it to /usr/local/lib/homelab/. systemd runs it as root every night.
# Settings come from /etc/homelab/backup.env (written by install.sh).
set -euo pipefail

source /etc/homelab/backup.env
# Variables in backup.env:
#   REPO PASSWORD_FILE KUBECONFIG MOUNT STATE_DIR
#   IMMICH_LIBRARY_GLOB VAULTWARDEN_DATA_GLOB NEXTCLOUD_APP_GLOB NEXTCLOUD_FILES

export RESTIC_REPOSITORY=$REPO
export RESTIC_PASSWORD_FILE=$PASSWORD_FILE
export RESTIC_CACHE_DIR=${CACHE_DIRECTORY:-/var/cache/restic}   # systemd provides this folder
export KUBECONFIG

TAG_HOST=homelab   # a fixed name keeps "keep the last N" rules stable, even if the PC is renamed

dump_dir=$(mktemp -d -p /var/tmp)    # holds the database dumps until restic has saved them
nextcloud_is_locked=no

# Always runs when the script ends, even after an error.
cleanup() {
  if [[ $nextcloud_is_locked == yes ]]; then
    nextcloud_occ maintenance:mode --off >/dev/null 2>&1 || true   # never leave Nextcloud locked
  fi
  rm -rf "$dump_dir"
}
trap cleanup EXIT

fail() { echo "$*" >&2; exit 1; }

# --- Helper functions ------------------------------------------------------------

# first_match PATTERN  Print the first folder that matches the pattern (empty if none).
# The app volumes have a generated name, so we find them with a pattern.
first_match() { compgen -G "$1" | head -1 || true; }

# dump_database NAMESPACE POD FILE  Save a copy of a Postgres database into FILE.
# A dump is safe while the database runs. Copying the live database files is not.
dump_database() {
  local namespace=$1 pod=$2 file=$3
  kubectl -n "$namespace" exec "$pod" -- \
    sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$file"
  [[ -s $file ]] || fail "the database dump is empty: $file"
}

# nextcloud_occ ARGS...  Run Nextcloud's command line tool (occ) inside its pod.
nextcloud_occ() {
  kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- su -s /bin/sh www-data -c "php occ $*"
}

# keep_recent TAG MONTHS  Delete old snapshots. Keep 7 daily, 4 weekly and MONTHS monthly ones.
keep_recent() {
  restic forget --host "$TAG_HOST" --tag "$1" --keep-daily 7 --keep-weekly 4 --keep-monthly "$2" --prune
}

# --- 1. Is the drive there? ----------------------------------------------------------
# Opening the folder makes the automount start. A real backup repository has a file
# called "config". The empty folder on the main disk does not, so a missing drive
# stops the backup here and can never fill the main disk.
ls "$MOUNT" >/dev/null 2>&1 || true
[[ -f $REPO/config ]] || fail "backup repository not found at $REPO (is the drive plugged in?)"

# --- 2. Immich: photo library + database ---------------------------------------------
library=$(first_match "$IMMICH_LIBRARY_GLOB")
[[ -n $library ]] || fail "Immich library folder not found: $IMMICH_LIBRARY_GLOB"
dump_database immich immich-postgres-0 "$dump_dir/immich.pgdump"
restic backup "$library" "$dump_dir/immich.pgdump" --tag immich --host "$TAG_HOST"
keep_recent immich 6

# --- 3. Vaultwarden: passwords ---------------------------------------------------------
# Skipped when the app is not installed.
# The SQLite file is in use, so ask the app for a safe copy first.
vaultwarden_data=$(first_match "$VAULTWARDEN_DATA_GLOB")
if [[ -n $vaultwarden_data ]]; then
  kubectl -n vaultwarden exec deploy/vaultwarden -- /vaultwarden backup
  restic backup "$vaultwarden_data" --tag vaultwarden --host "$TAG_HOST"
  keep_recent vaultwarden 12
fi

# --- 4. Nextcloud: files + database ----------------------------------------------------
# Skipped when the app is not installed.
# Maintenance mode stops writes, so the database and the files match each other.
nextcloud_app=$(first_match "$NEXTCLOUD_APP_GLOB")
if [[ -n $nextcloud_app ]]; then
  nextcloud_occ maintenance:mode --on
  nextcloud_is_locked=yes
  dump_database nextcloud nextcloud-postgres-0 "$dump_dir/nextcloud.pgdump"
  restic backup "$nextcloud_app" "$NEXTCLOUD_FILES" "$dump_dir/nextcloud.pgdump" --tag nextcloud --host "$TAG_HOST"
  nextcloud_occ maintenance:mode --off
  nextcloud_is_locked=no
  keep_recent nextcloud 12
fi

# --- 5. Integrity check (Sundays) ----------------------------------------------------
# Check the repository structure and read a random 5% of the data.
# Over many weeks this finds damage without reading everything each time.
if [[ $(date +%u) == 7 ]]; then restic check --read-data-subset=5%; fi

# --- 6. Record that the backup worked --------------------------------------------------
# The .prom file is read by Prometheus. The alert BackupStale fires when it gets old.
mkdir -p "$STATE_DIR"
now=$(date +%s)
echo "$now" > "$STATE_DIR/last-backup-success"
echo "homelab_backup_last_success_timestamp_seconds $now" > "$STATE_DIR/homelab_backup.prom.tmp"
mv "$STATE_DIR/homelab_backup.prom.tmp" "$STATE_DIR/homelab_backup.prom"
