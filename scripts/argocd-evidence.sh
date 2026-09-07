#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-togglemaster-fase3}"

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null

echo "===== ARGOCD PODS ====="
kubectl get pods -n argocd -o wide

echo
echo "===== ARGOCD APPLICATION ====="
kubectl get application togglemaster -n argocd \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'

echo
echo "===== TOGGLEMASTER DEPLOYMENTS ====="
kubectl get deployments -n togglemaster \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,IMAGE:.spec.template.spec.containers[0].image'

echo
echo "===== TOGGLEMASTER PODS ====="
kubectl get pods -n togglemaster -o wide

echo
echo "===== GITOPS SOURCE ====="
kubectl get application togglemaster -n argocd \
  -o jsonpath='repo={.spec.source.repoURL}{"\n"}revision={.spec.source.targetRevision}{"\n"}path={.spec.source.path}{"\n"}automated={.spec.syncPolicy.automated}{"\n"}'

echo
echo "Expected final state: SYNC=Synced and HEALTH=Healthy."
