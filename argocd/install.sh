#!/usr/bin/env bash
# install.sh - install Argo CD and hand the cluster over to GitOps.
# GitOps = Argo CD reads this repo on GitHub and makes the cluster match it.
# Preview by default. Use APPLY=1 to do it.
# Tip: do not run this during a big photo upload. Argo CD, Prometheus and Grafana
# need about 1.5 to 2 GB of memory, and Argo CD re-syncs Immich.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../bootstrap/scripts/lib.sh"
need kubectl sops openssl git

# renovate: datasource=github-releases depName=argoproj/argo-cd
ARGO_VERSION=v3.5.6   # check that this is still a supported release before you apply
SECRET_FILE=secrets/grafana-admin.enc.yaml

grafana_secret() {
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: grafana-admin, namespace: monitoring}
stringData: {admin-user: admin, admin-password: "$(random_password)"}
YAML
}

# Argo CD reads from GitHub, not from this disk. Refuse if GitHub is behind.
if [[ -n $(git status --porcelain) || -n $(git log origin/main..HEAD 2>/dev/null) ]]; then
  die "you have uncommitted or unpushed changes. Argo CD only sees what is on GitHub (main)."
fi

# 1. Argo CD "core": the controller, repo-server and redis only.
#    No web page, no login server. This saves memory.
#    (Want a web page? Run: argocd admin dashboard -n argocd)
#    --server-side is needed because the install files are large.
create_namespace argocd
run kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/core-install.yaml"

# 2. The Grafana admin password. Made once, then stored encrypted in git.
create_secret_file "$SECRET_FILE" grafana_secret
create_namespace monitoring
apply_secret "$SECRET_FILE"

# 3. Tell Argo CD where the repo is, then give it the root app. It deploys everything else.
run kubectl apply -f "$HERE/project-default.yaml"
run kubectl apply -f "$HERE/repos.yaml"
run kubectl apply -f "$HERE/root-app.yaml"
