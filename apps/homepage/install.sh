#!/usr/bin/env bash
# install.sh - create the private half of the Homepage config (link list with the
# Tailscale address), encrypt it with SOPS, and apply it. Dry run unless APPLY=1.
# The Deployment itself is deployed by Argo CD (argocd/apps/homepage.yaml).
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3

SECRET_REL=secrets/homepage.enc.yaml
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

run kubectl create namespace homepage --dry-run=client -o yaml
[[ $APPLY == 1 ]] && kubectl create namespace homepage --dry-run=client -o yaml | kubectl apply -f -

# Encrypted before it touches disk; the address never appears in git in plain text.
if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    ip=$(tailscale ip -4 | head -n1)
    fq=$(tailscale status --json | python3 -c "import json,sys;print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))")
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: homepage-private, namespace: homepage}
stringData:
  allowed-hosts: "$ip,localhost:30800"
  services.yaml: |
    - Apps:
        - Immich:
            description: Photos (iPhone backup)
            href: http://$ip:2283
        - Vaultwarden:
            description: Passwords
            href: https://$fq:8222
    - Operations:
        - Grafana:
            description: Dashboards and alerts
            href: http://$ip:3000
        - Prometheus:
            description: Metrics and queries
            href: http://$ip:9090
        - Argo CD:
            description: "No web UI in core mode. On the PC run: argocd admin dashboard -n argocd --port 8099"
            href: http://localhost:8099
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
  fi
fi
log "applying decrypted secret to the cluster (in memory only)"
[[ $APPLY == 1 ]] && sops -d "$SECRET_REL" | kubectl apply -f -
exit 0
