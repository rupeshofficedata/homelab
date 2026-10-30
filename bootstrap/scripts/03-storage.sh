#!/usr/bin/env bash
# 03-storage.sh - create the data folders and set up the backup drive.
# Safe to run again: it skips what already exists.
# It touches only $HOMELAB_ROOT, $BACKUP_MOUNT and one line in /etc/fstab.
# It never formats the drive and never writes files onto it.
source "$(dirname "$0")/lib.sh"
need findmnt chattr lsblk blkid

data_parent=$(dirname "$HOMELAB_ROOT")
[[ $(findmnt -no FSTYPE -T "$data_parent") == btrfs ]] || die "$data_parent is not btrfs"

# --- 1. Data folders --------------------------------------------------------------
#   k3s/      k3s system files
#   storage/  app volumes (databases, photo library, settings)
#   media/    movies and shows (Jellyfin reads them)
#   files/    user files (Nextcloud)
# "chattr +C" turns off copy-on-write for storage/. This is faster for databases.
# Only NEW files get the setting, so run it while the folder is still empty.
run sudo mkdir -p "$HOMELAB_ROOT"/{k3s,storage,media,files}
run sudo chattr +C "$HOMELAB_ROOT/storage"

# --- 2. Empty mount point for the backup drive ---------------------------------------
# "chattr +i" makes the empty folder read-only. If the drive is unplugged,
# a backup can then never fill the main disk by accident.
# The drive can still mount on top of it. Set this while nothing is mounted there.
if mountpoint -q "$BACKUP_MOUNT"; then die "$BACKUP_MOUNT is mounted. Unmount it first."; fi
run sudo mkdir -p "$BACKUP_MOUNT"
run sudo chattr +i "$BACKUP_MOUNT"

# --- 3. Mount the drive automatically --------------------------------------------------
# automount = the drive mounts the first time something opens the folder.
# nofail    = the computer still boots if the drive is unplugged.
device=$(sudo blkid -L "$BACKUP_LABEL") || die "no drive has the label '$BACKUP_LABEL'"
uuid=$(sudo blkid -s UUID -o value "$device")
mounted_at=$(findmnt -rno TARGET -S "UUID=$uuid" || true)
[[ -z $mounted_at ]] || die "the drive is already mounted at $mounted_at. Unmount it first: udisksctl unmount -b /dev/disk/by-uuid/$uuid"

if grep -q " $BACKUP_MOUNT " /etc/fstab; then
  log "/etc/fstab already has a line for $BACKUP_MOUNT: nothing to add"
else
  fstab_line="UUID=$uuid $BACKUP_MOUNT exfat uid=$(id -u),gid=$(id -g),umask=022,nofail,x-systemd.automount,x-systemd.idle-timeout=60 0 0"
  run sudo sh -c "printf '%s\n' '$fstab_line' >> /etc/fstab"
  run sudo systemctl daemon-reload
  run sudo systemctl start "$(systemd-escape -p --suffix=automount "$BACKUP_MOUNT")"
fi
