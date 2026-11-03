#!/usr/bin/env bash
# Run only after the intended cluster is restored and its context is verified.
set -euo pipefail
set +x
: "${PHASE4_SECRET_DIR:?Set PHASE4_SECRET_DIR to the local directory containing integration files}"
: "${EXPECTED_CONTEXT:?Set EXPECTED_CONTEXT to the approved Kubernetes context}"
[[ "$(kubectl config current-context)" == "$EXPECTED_CONTEXT" ]] || { echo 'Wrong Kubernetes context' >&2; exit 1; }
pd="$PHASE4_SECRET_DIR/pagerduty-routing-key"
[[ -f "$pd" ]] || pd="$pd.txt"
for path in "$pd" "$PHASE4_SECRET_DIR/datadog-api-key" "$PHASE4_SECRET_DIR/discord-webhook"; do
  [[ -s "$path" ]] || { echo 'Required integration file is missing or empty' >&2; exit 1; }
done
# Stable files preserve shared credentials when this script is run again.
umask 077
for key in healer-token grafana-password; do
  if [[ ! -s "$PHASE4_SECRET_DIR/$key" ]]; then
    openssl rand -hex 32 | tr -d '\n' > "$PHASE4_SECRET_DIR/$key"
  fi
done
printf 'admin' > "$PHASE4_SECRET_DIR/grafana-username"
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace togglemaster --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n observability create secret generic observability-integrations \
  --from-file=pagerduty-routing-key="$pd" \
  --from-file=datadog-api-key="$PHASE4_SECRET_DIR/datadog-api-key" \
  --from-file=discord-webhook="$PHASE4_SECRET_DIR/discord-webhook" \
  --from-file=healer-token="$PHASE4_SECRET_DIR/healer-token" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n observability create secret generic grafana-admin \
  --from-file=username="$PHASE4_SECRET_DIR/grafana-username" \
  --from-file=password="$PHASE4_SECRET_DIR/grafana-password" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n togglemaster create secret generic self-healer-auth \
  --from-file=token="$PHASE4_SECRET_DIR/healer-token" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo 'Integration secrets installed; values were not printed.'
