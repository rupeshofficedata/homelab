#!/usr/bin/env bash
# install.sh - prepare the start page (Homepage): the list of links to every app.
# The links contain your Tailscale address, so the list is stored as an encrypted secret.
# Run it once, before Argo CD deploys the app (argocd/apps/homepage.yaml).
# Preview by default. Use APPLY=1 to do it.
#
# To add or change a link: edit the list below, delete secrets/homepage.enc.yaml,
# run this script again with APPLY=1, and commit the new encrypted file.
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3

SECRET_FILE=secrets/homepage.enc.yaml

private_settings() {
  local ip host
  ip=$(tailscale ip -4 | head -n1)
  host=$(tailnet_name)
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: homepage-private, namespace: homepage}
stringData:
  allowed-hosts: "$ip,localhost:30800"
  services.yaml: |
    - Apps:
        - Immich:
            description: Photos
            href: http://$ip:2283
        - Jellyfin:
            description: Movies and shows
            href: http://$ip:8096
        - qBittorrent:
            description: Torrent downloads
            href: http://$ip:8081
        - Nextcloud:
            description: Files and sync
            href: https://$host:8443
        - Vaultwarden:
            description: Passwords
            href: https://$host:8222
    - Operations:
        - Grafana:
            description: Dashboards and alerts
            href: http://$ip:3000
        - Prometheus:
            description: Metrics and queries
            href: http://$ip:9090
        - Argo CD:
            description: "No web page by default. Run: argocd admin dashboard -n argocd --port 8099"
            href: http://localhost:8099
YAML
}

create_namespace homepage
create_secret_file "$SECRET_FILE" private_settings
apply_secret "$SECRET_FILE"
