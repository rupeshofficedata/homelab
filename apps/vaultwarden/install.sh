#!/usr/bin/env bash
# install.sh - create the private half of the Vaultwarden config (DOMAIN with the
# tailnet name), encrypt it with SOPS and apply it. Dry run unless APPLY=1.
# The Deployment is deployed by Argo CD (argocd/apps/vaultwarden.yaml).
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3

SECRET_REL=secrets/vaultwarden.enc.yaml
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

run kubectl create namespace vaultwarden --dry-run=client -o yaml
[[ $APPLY == 1 ]] && kubectl create namespace vaultwarden --dry-run=client -o yaml | kubectl apply -f -

if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    fq=$(tailscale status --json | python3 -c "import json,sys;print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))")
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: vaultwarden-private, namespace: vaultwarden}
stringData: {domain: "https://$fq:8222"}
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
  fi
fi
log "applying decrypted secret to the cluster (in memory only)"
[[ $APPLY == 1 ]] && sops -d "$SECRET_REL" | kubectl apply -f -
exit 0
