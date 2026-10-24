#!/usr/bin/env bash
# install.sh - create the user-files folder and the private half of the Nextcloud
# config (passwords + tailnet name), encrypt it with SOPS, apply it. Dry run unless APPLY=1.
# The workloads are deployed by Argo CD (argocd/apps/nextcloud.yaml).
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl sops tailscale python3 openssl

SECRET_REL=secrets/nextcloud.enc.yaml
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

# Files folder: the pod's www-data (uid 33) must own it.
run sudo install -d -o 33 -g 33 "$HOMELAB_ROOT/files"
run kubectl create namespace nextcloud --dry-run=client -o yaml
[[ $APPLY == 1 ]] && kubectl create namespace nextcloud --dry-run=client -o yaml | kubectl apply -f -

if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    fq=$(tailscale status --json | python3 -c "import json,sys;print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))")
    dbpw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')
    adminpw=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9')
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: nextcloud-private, namespace: nextcloud}
stringData:
  db-password: "$dbpw"
  admin-user: admin
  admin-password: "$adminpw"
  host: "$fq"
  host-port: "$fq:8443"
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
  fi
fi
log "applying decrypted secret to the cluster (in memory only)"
[[ $APPLY == 1 ]] && sops -d "$SECRET_REL" | kubectl apply -f -
exit 0
