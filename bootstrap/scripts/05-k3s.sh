#!/usr/bin/env bash
# 05-k3s.sh - install k3s (a small, single-node Kubernetes) with this repo's settings.
# It downloads the official installer and runs it as root, so the dry run shows you the steps first.
source "$(dirname "$0")/lib.sh"
need curl sed
[[ -d $HOMELAB_ROOT/storage ]] || die "run 03-storage.sh first"

# Fill the data folder into the config template, then install it where k3s looks for it.
config=$(mktemp); installer=$(mktemp)
trap 'rm -f "$config" "$installer"' EXIT
sed "s|@HOMELAB_ROOT@|$HOMELAB_ROOT|g" "$BOOT_DIR/k3s-config.yaml" > "$config"
run sudo install -D -m 600 "$config" /etc/rancher/k3s/config.yaml

# Save the installer to a file first, so you can read it before it runs.
# It follows the "stable" k3s release. To lock a version, add INSTALL_K3S_VERSION=<version>.
run curl -sfL https://get.k3s.io -o "$installer"
run sudo env INSTALL_K3S_CHANNEL=stable sh "$installer"

# Give your user its own kubeconfig file (kubectl reads it to find the cluster).
run mkdir -p "$(dirname "$KUBECONFIG_OUT")"
run sudo install -o "$USER" -m 600 /etc/rancher/k3s/k3s.yaml "$KUBECONFIG_OUT"
log "use it in bash or zsh with:  export KUBECONFIG=$KUBECONFIG_OUT"
