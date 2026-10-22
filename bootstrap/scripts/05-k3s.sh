#!/usr/bin/env bash
# 05-k3s.sh - install single-node k3s with the repo's config.
# Runs the official installer (get.k3s.io) as root: read $tmp first if unsure.
source "$(dirname "$0")/lib.sh"
need curl sed
[[ -d $HOMELAB_ROOT/storage ]] || die "run 03-storage.sh first"

# Render the config template (single source of truth: config.env).
cfg=$(mktemp); script=$(mktemp); trap 'rm -f "$cfg" "$script"' EXIT
sed "s|@HOMELAB_ROOT@|$HOMELAB_ROOT|g" "$BOOT_DIR/k3s-config.yaml" > "$cfg"
run sudo install -D -m 600 "$cfg" /etc/rancher/k3s/config.yaml

# Download first, then run, so the script is on disk and inspectable.
# ponytail: tracks the stable channel; pin INSTALL_K3S_VERSION once it works.
run curl -sfL https://get.k3s.io -o "$script"
run sudo env INSTALL_K3S_CHANNEL=stable sh "$script"

# Separate kubeconfig: existing kind contexts in ~/.kube/config stay untouched.
run mkdir -p "$(dirname "$KUBECONFIG_OUT")"
run sudo install -o "$USER" -m 600 /etc/rancher/k3s/k3s.yaml "$KUBECONFIG_OUT"
log "use it:  bash/zsh: export KUBECONFIG=$KUBECONFIG_OUT   fish: set -x KUBECONFIG $KUBECONFIG_OUT"
