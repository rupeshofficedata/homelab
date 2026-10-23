#!/usr/bin/env bash
# install.sh - Phase 1b: install Argo CD (core) and hand the cluster to GitOps.
# Dry run unless APPLY=1. Do NOT run while a big photo upload is in progress:
# Argo, Prometheus and Grafana add ~1.5-2 GB RAM and Argo re-syncs Immich.
source "$(dirname "$0")/../bootstrap/scripts/lib.sh"
need kubectl sops openssl

# renovate: datasource=github-releases depName=argoproj/argo-cd
ARGO_VERSION=v3.4.12   # pinned; verify it is still a supported release before applying
HERE=$(cd "$(dirname "$0")" && pwd)
SECRET_REL=secrets/grafana-admin.enc.yaml
export KUBECONFIG=${KUBECONFIG:-$KUBECONFIG_OUT}
export SOPS_AGE_KEY_FILE=$AGE_KEY_FILE
cd "$REPO_DIR"

# Refuse to hand over a repo that Argo cannot read: it pulls from GitHub, not this disk.
if [[ -n $(git status --porcelain) || -n $(git log origin/main..HEAD 2>/dev/null) ]]; then
  die "uncommitted or unpushed changes: Argo only sees what is on GitHub main"
fi

# 1. Argo CD "core": controller + repo-server + redis, no UI/API server/dex (saves RAM).
#    Use `argocd admin dashboard` if you want the UI. --server-side: CRDs are large.
run kubectl create namespace argocd --dry-run=client -o yaml
if [[ $APPLY == 1 ]]; then
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
fi
run kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/core-install.yaml"

# 2. Grafana admin secret: generated once, committed ENCRYPTED, applied in memory.
if [[ ! -f $SECRET_REL ]]; then
  log "creating $SECRET_REL"
  if [[ $APPLY == 1 ]]; then
    pw=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')
    sops -e --filename-override "$SECRET_REL" --input-type yaml --output-type yaml /dev/stdin > "$SECRET_REL.tmp" <<YAML
apiVersion: v1
kind: Secret
metadata: {name: grafana-admin, namespace: monitoring}
stringData: {admin-user: admin, admin-password: "$pw"}
YAML
    mv "$SECRET_REL.tmp" "$SECRET_REL"
    log "commit $SECRET_REL (encrypted) so it survives a rebuild"
  fi
fi
if [[ $APPLY == 1 ]]; then
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  sops -d "$SECRET_REL" | kubectl apply -f -
fi

# 3. Repo credentials for the OCI chart, then the root app: Argo takes over from here.
run kubectl apply -f "$HERE/project-default.yaml"
run kubectl apply -f "$HERE/repos.yaml"
run kubectl apply -f "$HERE/root-app.yaml"
