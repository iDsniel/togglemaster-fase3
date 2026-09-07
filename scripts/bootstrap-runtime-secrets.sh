#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform/environments/dev"
NAMESPACE="togglemaster"
SECRET_NAME="togglemaster-runtime-secrets"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-togglemaster-fase3}"

for cmd in aws terraform kubectl jq python3 openssl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  }
done

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

RDS_SECRET_ARNS="$(terraform -chdir="$TF_DIR" output -json rds_secret_arns)"
RDS_ENDPOINTS="$(terraform -chdir="$TF_DIR" output -json rds_endpoints)"

build_database_url() {
  local logical_name="$1"
  local db_name="$2"
  local secret_arn endpoint secret_json username password host port

  secret_arn="$(jq -r --arg key "$logical_name" '.[$key]' <<<"$RDS_SECRET_ARNS")"
  endpoint="$(jq -r --arg key "$logical_name" '.[$key]' <<<"$RDS_ENDPOINTS")"

  if [[ -z "$secret_arn" || "$secret_arn" == "null" || -z "$endpoint" || "$endpoint" == "null" ]]; then
    echo "ERROR: Terraform output missing for database: $logical_name" >&2
    exit 1
  fi

  secret_json="$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$secret_arn" \
    --query SecretString \
    --output text)"

  username="$(jq -r '.username' <<<"$secret_json")"
  password="$(jq -r '.password' <<<"$secret_json")"
  host="${endpoint%:*}"
  port="${endpoint##*:}"

  DB_USER="$username" DB_PASS="$password" DB_HOST="$host" DB_PORT="$port" DB_NAME="$db_name" python3 <<'PY'
import os
from urllib.parse import quote

user = quote(os.environ["DB_USER"], safe="")
password = quote(os.environ["DB_PASS"], safe="")
host = os.environ["DB_HOST"]
port = os.environ["DB_PORT"]
db = os.environ["DB_NAME"]
print(f"postgresql://{user}:{password}@{host}:{port}/{db}?sslmode=require")
PY
}

AUTH_DATABASE_URL="$(build_database_url auth authdb)"
FLAG_DATABASE_URL="$(build_database_url flag flagdb)"
TARGETING_DATABASE_URL="$(build_database_url targeting targetingdb)"

if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  MASTER_KEY="$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.master_key}' | base64 -d)"
else
  MASTER_KEY="$(openssl rand -hex 32)"
fi

kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=auth_database_url="$AUTH_DATABASE_URL" \
  --from-literal=flag_database_url="$FLAG_DATABASE_URL" \
  --from-literal=targeting_database_url="$TARGETING_DATABASE_URL" \
  --from-literal=master_key="$MASTER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

unset AUTH_DATABASE_URL FLAG_DATABASE_URL TARGETING_DATABASE_URL MASTER_KEY RDS_SECRET_ARNS RDS_ENDPOINTS

echo "Runtime secret '$SECRET_NAME' is present in namespace '$NAMESPACE'."
echo "No secret values were written to Git or printed to stdout."
