#!/usr/bin/env bash
# install.sh - install or upgrade Immich on k3s (Phase 1a: manual Helm, no Argo yet).
# Dry run unless APPLY=1. Idempotent: re-run to upgrade after editing values.yaml.
source "$(dirname "$0")/../../bootstrap/scripts/lib.sh"
need kubectl helm sops openssl

CHART_VERSION=0.13.4   # pinned; Renovate will propose bumps in Phase 1b
HERE=$(cd "$(dirname "$0")" && pwd)
SECRET_REL=secrets/immich-db.enc.yaml
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

run kubectl apply -f "$HERE/namespace.yaml"

# 1. DB secret: generated once, committed ENCRYPTED. Plaintext never touches disk.
if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    pw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: immich-db, namespace: immich}
stringData: {host: immich-postgres, user: immich, dbname: immich, password: "$pw"}
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
  fi
fi
log "applying decrypted secret to the cluster (in memory only)"
if [[ $APPLY == 1 ]]; then sops -d "$SECRET_REL" | kubectl apply -f -; fi

# 2. Volume + database, then the app.
run kubectl apply -f "$HERE/pvc.yaml" -f "$HERE/postgres.yaml" -f "$HERE/nodeport.yaml"
run helm upgrade --install immich oci://ghcr.io/immich-app/immich-charts/immich \
  --version "$CHART_VERSION" --namespace immich -f "$HERE/values.yaml"
