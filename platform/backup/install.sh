#!/usr/bin/env bash
# install.sh - set up the restic repo and the nightly systemd timer.
# Dry run unless APPLY=1. Idempotent. Needs the drive mounted (03-storage.sh done).
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need restic sops openssl systemctl

HERE=$(cd "$(dirname "$0")" && pwd)
SECRET_REL=secrets/restic.enc.yaml
REPO=$BACKUP_MOUNT/homelab-restic
PW_FILE=/etc/homelab/restic-password
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

# 1. Repo password: generated once, committed ENCRYPTED. Recoverable with the age key.
if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    pw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: restic, namespace: homelab}
stringData: {password: "$pw"}
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
  fi
fi

# 2. Unattended runs need the password on disk: root-only file, outside the repo.
run sudo install -d -m 700 /etc/homelab
if [[ $APPLY == 1 ]]; then
  sops -d --extract '["stringData"]["password"]' "$SECRET_REL" | sudo install -m 600 /dev/stdin "$PW_FILE"
fi

# 3. Repo on the drive. `ls` triggers the automount; refuse to init on the bare SSD mountpoint.
if [[ $APPLY == 1 ]]; then
  ls "$BACKUP_MOUNT" >/dev/null
  [[ $(findmnt -no FSTYPE -T "$BACKUP_MOUNT" | tail -1) == exfat ]] || die "drive not mounted at $BACKUP_MOUNT"
  sudo test -f "$REPO/config" || { mkdir -p "$REPO"; sudo restic -r "$REPO" --password-file "$PW_FILE" init; }
fi

# 4. Config, script, units.
env_file=$(mktemp); trap 'rm -f "$env_file"' EXIT
cat > "$env_file" <<ENV
REPO=$REPO
PASSWORD_FILE=$PW_FILE
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
DATA_GLOB=$HOMELAB_ROOT/storage/*_immich_immich-library
VW_GLOB=$HOMELAB_ROOT/storage/*_vaultwarden_vaultwarden-data
NC_GLOB=$HOMELAB_ROOT/storage/*_nextcloud_nextcloud-html
NC_DATA=$HOMELAB_ROOT/files
MOUNT=$BACKUP_MOUNT
STATE_DIR=/var/lib/homelab
ENV
run sudo install -m 644 "$env_file" /etc/homelab/backup.env
run sudo install -D -m 755 "$HERE/backup.sh" /usr/local/lib/homelab/backup.sh
run sudo install -m 644 "$HERE/homelab-backup.service" "$HERE/homelab-backup.timer" /etc/systemd/system/
run sudo systemctl daemon-reload
run sudo systemctl enable --now homelab-backup.timer
