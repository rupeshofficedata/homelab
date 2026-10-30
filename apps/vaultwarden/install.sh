#!/usr/bin/env bash
# install.sh - prepare the private settings for Vaultwarden (password manager).
# It stores the web address (which contains your Tailscale name) as an encrypted secret.
# Run it once, before Argo CD deploys the app (argocd/apps/vaultwarden.yaml).
# Preview by default. Use APPLY=1 to do it.
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3

SECRET_FILE=secrets/vaultwarden.enc.yaml

private_settings() {
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: vaultwarden-private, namespace: vaultwarden}
stringData: {domain: "https://$(tailnet_name):8222"}
YAML
}

create_namespace vaultwarden
create_secret_file "$SECRET_FILE" private_settings
apply_secret "$SECRET_FILE"
