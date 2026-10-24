#!/usr/bin/env bash
# 03-storage.sh - data directories on the SSD and the backup-drive mount.
# Idempotent: safe to re-run. Touches only $HOMELAB_ROOT, $BACKUP_MOUNT and
# one line in /etc/fstab. Never formats or writes to the drive itself.
source "$(dirname "$0")/lib.sh"
need findmnt chattr lsblk

[[ $(findmnt -no FSTYPE -T "$(dirname "$HOMELAB_ROOT")") == btrfs ]] || die "$(dirname "$HOMELAB_ROOT") is not btrfs"

# 1. Data dirs. +C = no copy-on-write (better for Postgres, fewer fragments).
#    New files inherit +C, so set it while the dir is still empty.
# ponytail: +C covers photos too (loses btrfs checksums for them); split Postgres out if you want bit-rot detection.
run sudo mkdir -p "$HOMELAB_ROOT"/{k3s,storage,media}   # media: Jellyfin library, mount the big drive here
run sudo chattr +C "$HOMELAB_ROOT/storage"

# 2. Backup mountpoint. +i on the EMPTY directory makes writes fail while the
#    drive is absent, so a backup job can never fill the SSD by accident.
#    It must be set while nothing is mounted there.
mountpoint -q "$BACKUP_MOUNT" && die "$BACKUP_MOUNT is mounted; unmount it first"
run sudo mkdir -p "$BACKUP_MOUNT"
run sudo chattr +i "$BACKUP_MOUNT"

# 3. fstab entry by UUID. automount = mounts on first access, nofail = boot
#    never hangs when the drive is unplugged.
dev=$(sudo blkid -L "$BACKUP_LABEL") || die "no drive labelled '$BACKUP_LABEL'"   # -L prints the device path
uuid=$(sudo blkid -s UUID -o value "$dev")
other=$(findmnt -rno TARGET -S "UUID=$uuid" || true)
[[ -z $other ]] || die "drive already mounted at $other; unmount it first (udisksctl unmount -b /dev/disk/by-uuid/$uuid)"

if grep -q " $BACKUP_MOUNT " /etc/fstab; then
  log "fstab entry for $BACKUP_MOUNT exists; nothing to add"
else
  line="UUID=$uuid $BACKUP_MOUNT exfat uid=$(id -u),gid=$(id -g),umask=022,nofail,x-systemd.automount,x-systemd.idle-timeout=60 0 0"
  run sudo sh -c "printf '%s\n' '$line' >> /etc/fstab"
  run sudo systemctl daemon-reload
  run sudo systemctl start "$(systemd-escape -p --suffix=automount "$BACKUP_MOUNT")"
fi
