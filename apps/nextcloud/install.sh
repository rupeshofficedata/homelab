#!/usr/bin/env bash
# install.sh - prepare Nextcloud (file sync): the files folder and the private settings.
# The settings (passwords and your Tailscale name) are stored as an encrypted secret.
# Run it once, before Argo CD deploys the app (argocd/apps/nextcloud.yaml).
# Preview by default. Use APPLY=1 to do it.
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3 openssl

SECRET_FILE=secrets/nextcloud.enc.yaml
WWW_DATA_UID=33   # the user Nextcloud runs as inside its container

private_settings() {
  local host
  host=$(tailnet_name)
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: nextcloud-private, namespace: nextcloud}
stringData:
  db-password: "$(random_password)"
  admin-user: admin
  admin-password: "$(random_password)"
  host: "$host"
  host-port: "$host:8443"
YAML
}

# The folder for user files must belong to the Nextcloud user.
run sudo install -d -o "$WWW_DATA_UID" -g "$WWW_DATA_UID" "$HOMELAB_ROOT/files"
create_namespace nextcloud
create_secret_file "$SECRET_FILE" private_settings
apply_secret "$SECRET_FILE"
