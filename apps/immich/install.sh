#!/usr/bin/env bash
# install.sh - install or upgrade Immich (photo library) on k3s.
# Safe to run again: re-run it after you edit values.yaml to upgrade.
# Preview by default. Use APPLY=1 to do it.
HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/../../bootstrap/scripts/lib.sh"
need kubectl helm sops openssl

CHART_VERSION=0.13.4          # version of the Immich Helm chart. Change it on purpose.
SECRET_FILE=secrets/immich-db.enc.yaml

# The database login. Made once, then stored encrypted in git.
database_secret() {
  cat <<YAML
apiVersion: v1
kind: Secret
metadata: {name: immich-db, namespace: immich}
stringData: {host: immich-postgres, user: immich, dbname: immich, password: "$(random_password)"}
YAML
}

# 1. Namespace and database password
run kubectl apply -f "$HERE/namespace.yaml"
create_secret_file "$SECRET_FILE" database_secret
apply_secret "$SECRET_FILE"

# 2. Storage, database and network entry point
run kubectl apply -f "$HERE/pvc.yaml" -f "$HERE/postgres.yaml" -f "$HERE/nodeport.yaml"

# 3. The Immich app itself
run helm upgrade --install immich oci://ghcr.io/immich-app/immich-charts/immich \
  --version "$CHART_VERSION" --namespace immich -f "$HERE/values.yaml"
