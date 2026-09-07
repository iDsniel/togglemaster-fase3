#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="togglemaster"
SECRET_NAME="togglemaster-runtime-secrets"

command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found" >&2; exit 1; }

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null

run_schema() {
  local name="$1"
  local secret_key="$2"
  local sql_file="$3"
  local pod="schema-init-${name}"

  kubectl delete pod "$pod" -n "$NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: psql
      image: postgres:16-alpine
      command: ["sh", "-c", "sleep 600"]
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: ${SECRET_NAME}
              key: ${secret_key}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
EOF

  kubectl wait --for=condition=Ready "pod/$pod" -n "$NAMESPACE" --timeout=120s >/dev/null
  kubectl exec -i "$pod" -n "$NAMESPACE" -- sh -c 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1' < "$ROOT_DIR/$sql_file"
  kubectl delete pod "$pod" -n "$NAMESPACE" --wait=false >/dev/null
  echo "Schema applied: $name"
}

run_schema auth auth_database_url auth-service/db/init.sql
run_schema flag flag_database_url flag-service/db/init.sql
run_schema targeting targeting_database_url targeting-service/db/init.sql

echo "All PostgreSQL schemas initialized successfully."
