#!/usr/bin/env bash
# install.sh - set up the nightly backup: password, restic repository, config and timer.
# Safe to run again. The backup drive must be plugged in (see 03-storage.sh).
# Preview by default. Use APPLY=1 to do it.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../../bootstrap/scripts/lib.sh"
need restic sops openssl systemctl

SECRET_FILE=secrets/restic.enc.yaml
REPO=$BACKUP_MOUNT/homelab-restic          # the backup repository, on the drive
PASSWORD_FILE=/etc/homelab/restic-password # readable by root only

restic_secret() {
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: restic, namespace: homelab}
stringData: {password: "$(random_password)"}
YAML
}

# 1. The repository password. Made once, then stored encrypted in git.
#    Anyone with the age key can get it back from there.
create_secret_file "$SECRET_FILE" restic_secret

# 2. The nightly job runs with nobody logged in, so it needs the password in a file.
#    The file is readable by root only and is not inside the repo.
run sudo install -d -m 700 /etc/homelab
if [[ $APPLY == 1 ]]; then
  sops -d --extract '["stringData"]["password"]' "$SECRET_FILE" | sudo install -m 600 /dev/stdin "$PASSWORD_FILE"
fi

# 3. Create the repository on the drive.
#    "ls" makes the drive mount. Refuse to continue if the drive is not really there.
if [[ $APPLY == 1 ]]; then
  ls "$BACKUP_MOUNT" >/dev/null
  [[ $(findmnt -no FSTYPE -T "$BACKUP_MOUNT" | tail -1) == exfat ]] || die "the drive is not mounted at $BACKUP_MOUNT"
  if ! sudo test -f "$REPO/config"; then
    mkdir -p "$REPO"
    sudo restic -r "$REPO" --password-file "$PASSWORD_FILE" init
  fi
fi

# 4. Write the settings file that backup.sh reads.
settings=$(mktemp)
trap 'rm -f "$settings"' EXIT
cat > "$settings" <<ENV
REPO=$REPO
PASSWORD_FILE=$PASSWORD_FILE
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
MOUNT=$BACKUP_MOUNT
STATE_DIR=/var/lib/homelab
IMMICH_LIBRARY_GLOB=$HOMELAB_ROOT/storage/*_immich_immich-library
VAULTWARDEN_DATA_GLOB=$HOMELAB_ROOT/storage/*_vaultwarden_vaultwarden-data
NEXTCLOUD_APP_GLOB=$HOMELAB_ROOT/storage/*_nextcloud_nextcloud-html
NEXTCLOUD_FILES=$HOMELAB_ROOT/files
ENV

# 5. Install the settings, the script and the timer. Then start the timer.
run sudo install -m 644 "$settings" /etc/homelab/backup.env
run sudo install -D -m 755 "$HERE/backup.sh" /usr/local/lib/homelab/backup.sh
run sudo install -m 644 "$HERE/homelab-backup.service" "$HERE/homelab-backup.timer" /etc/systemd/system/
run sudo systemctl daemon-reload
run sudo systemctl enable --now homelab-backup.timer
