#!/usr/bin/env bash
# 01-preflight.sh - READ-ONLY health check. Safe to run any time, changes nothing.
# Prints "ok" or "FIX" per check and the pacman command for missing tools.
export READONLY=1
source "$(dirname "$0")/lib.sh"

check() { local label=$1; shift; if "$@" >/dev/null 2>&1; then log "ok    $label"; else warn "FIX   $label"; fi; }

# --- tools -----------------------------------------------------------------
missing=()
for c in btrfs chattr findmnt curl git docker helm kubectl age sops gitleaks restic tailscale; do
  check "command: $c" command -v "$c" || true
  command -v "$c" >/dev/null || missing+=("$c")
done
# k3s itself is installed by 05-k3s.sh, not pacman.
(( ${#missing[@]} )) && warn "install: sudo pacman -S ${missing[*]}"

# --- resources ---------------------------------------------------------------
avail_mb=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
swap_mb=$(awk '/SwapTotal/{t=$2}/SwapFree/{f=$2}END{print int((t-f)/1024)}' /proc/meminfo)
check "RAM available >= 4096 MB (now ${avail_mb} MB; run 02-free-ram.sh)" test "$avail_mb" -ge 4096
check "swap in use < 2048 MB (now ${swap_mb} MB)" test "$swap_mb" -lt 2048
free_gb=$(df -BG --output=avail "$(dirname "$HOMELAB_ROOT")" | tail -1 | tr -dc 0-9)
check "free disk on $(dirname "$HOMELAB_ROOT") >= 100 GB (now ${free_gb} GB)" test "$free_gb" -ge 100
check "$(dirname "$HOMELAB_ROOT") is btrfs" test "$(findmnt -no FSTYPE -T "$(dirname "$HOMELAB_ROOT")")" = btrfs

# --- drive -----------------------------------------------------------------
check "backup drive labelled '$BACKUP_LABEL' present" sudo blkid -L "$BACKUP_LABEL"
check "$BACKUP_MOUNT is in /etc/fstab" grep -q " $BACKUP_MOUNT " /etc/fstab

# --- containers and ports ------------------------------------------------------
running=$(docker ps --format '{{.Names}}' | grep -cE "$STOP_REGEX" || true)
check "no containers matching STOP_REGEX running (now $running)" test "$running" -eq 0
check "port 6443 free (k3s API)" bash -c '! ss -ltn | grep -q ":6443 "'
