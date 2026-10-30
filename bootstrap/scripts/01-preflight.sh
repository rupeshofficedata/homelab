#!/usr/bin/env bash
# 01-preflight.sh - check that this machine is ready. It changes NOTHING.
# Each check prints "ok" or "FIX". Fix every FIX line before you continue.
export READONLY=1   # tells lib.sh this script never changes anything
source "$(dirname "$0")/lib.sh"

# check "description" COMMAND...   -> prints ok if the command succeeds, FIX if not.
check() {
  local description=$1; shift
  if "$@" >/dev/null 2>&1; then log "ok    $description"; else warn "FIX   $description"; fi
}

# --- Programs ---------------------------------------------------------------
# k3s is not in this list: script 05 installs it.
missing=()
for program in btrfs chattr findmnt curl git docker helm kubectl age sops gitleaks restic tailscale; do
  check "program installed: $program" command -v "$program"
  command -v "$program" >/dev/null || missing+=("$program")
done
if (( ${#missing[@]} )); then warn "install these with your package manager: ${missing[*]}"; fi

# --- Memory and disk ----------------------------------------------------------
free_ram_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
swap_used_mb=$(awk '/SwapTotal/ {total=$2} /SwapFree/ {free=$2} END {print int((total-free)/1024)}' /proc/meminfo)
data_parent=$(dirname "$HOMELAB_ROOT")
free_disk_gb=$(df -BG --output=avail "$data_parent" | tail -1 | tr -dc 0-9)

check "free memory is at least 4096 MB (now $free_ram_mb MB)" test "$free_ram_mb" -ge 4096
check "swap in use is below 2048 MB (now $swap_used_mb MB)" test "$swap_used_mb" -lt 2048
check "free disk space on $data_parent is at least 100 GB (now $free_disk_gb GB)" test "$free_disk_gb" -ge 100
check "$data_parent uses the btrfs filesystem" test "$(findmnt -no FSTYPE -T "$data_parent")" = btrfs

# --- Backup drive -----------------------------------------------------------------
check "backup drive with label '$BACKUP_LABEL' is plugged in" sudo blkid -L "$BACKUP_LABEL"
check "$BACKUP_MOUNT is listed in /etc/fstab" grep -q " $BACKUP_MOUNT " /etc/fstab

# --- Containers and ports ---------------------------------------------------------
if [[ -n $STOP_CONTAINERS_REGEX ]]; then
  matching=$(docker ps --format '{{.Names}}' | grep -cE "$STOP_CONTAINERS_REGEX" || true)
  check "no running containers match STOP_CONTAINERS_REGEX (now $matching)" test "$matching" -eq 0
fi
check "port 6443 is free (k3s uses it)" bash -c '! ss -ltn | grep -q ":6443 "'
