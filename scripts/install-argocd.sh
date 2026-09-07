#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-togglemaster-fase3}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.4.0}"
APP_NAMESPACE="togglemaster"

for cmd in aws kubectl helm jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  }
done

echo "==> Updating kubeconfig for $CLUSTER_NAME"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

CURRENT_CONTEXT="$(kubectl config current-context)"
echo "Kubernetes context: $CURRENT_CONTEXT"

if ! kubectl get secret togglemaster-runtime-secrets -n "$APP_NAMESPACE" >/dev/null 2>&1; then
  echo "ERROR: Gate 6 runtime secret is missing in namespace '$APP_NAMESPACE'." >&2
  echo "Run: bash scripts/bootstrap-runtime-secrets.sh" >&2
  exit 1
fi

ASSOCIATIONS="$(aws eks list-pod-identity-associations \
  --cluster-name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --output json)"

for sa in evaluation-service analytics-service; do
  if ! jq -e --arg sa "$sa" '.associations[]? | select(.namespace == "togglemaster" and .serviceAccount == $sa)' <<<"$ASSOCIATIONS" >/dev/null; then
    echo "ERROR: Gate 6 Pod Identity association is missing for service account '$sa'." >&2
    echo "Apply terraform/environments/dev before installing ArgoCD." >&2
    exit 1
  fi
done

echo "==> Gate 6 prerequisites validated"

echo "==> Installing ArgoCD chart $ARGOCD_CHART_VERSION"
helm repo add argo https://argoproj.github.io/argo-helm --force-update >/dev/null
helm repo update >/dev/null

helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --values "$ROOT_DIR/argocd/values.yaml" \
  --atomic \
  --wait \
  --timeout 10m

echo "==> Waiting for ArgoCD control plane"
kubectl rollout status deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE" --timeout=300s

if kubectl get deployment argocd-applicationset-controller -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
  kubectl rollout status deployment/argocd-applicationset-controller -n "$ARGOCD_NAMESPACE" --timeout=300s
fi

echo "==> Applying ToggleMaster AppProject and Application"
kubectl apply -f "$ROOT_DIR/argocd/togglemaster-application.yaml"

echo "==> Waiting for automatic GitOps synchronization"
kubectl wait application/togglemaster \
  -n "$ARGOCD_NAMESPACE" \
  --for=jsonpath='{.status.sync.status}'=Synced \
  --timeout=600s

kubectl wait application/togglemaster \
  -n "$ARGOCD_NAMESPACE" \
  --for=jsonpath='{.status.health.status}'=Healthy \
  --timeout=600s

echo
echo "Gate 7 completed: ArgoCD is installed and ToggleMaster is Synced/Healthy."
echo "Safe local UI access: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "Then browse to: http://localhost:8080"
echo "Do not expose or record the ArgoCD admin password."
