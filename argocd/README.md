# Gate 7 — ArgoCD

This directory contains the declarative ArgoCD configuration used by ToggleMaster Phase 3.

## Architecture

- ArgoCD is installed in namespace `argocd` with the official `argo/argo-cd` Helm chart.
- Chart version is pinned by `scripts/install-argocd.sh` (`10.4.0` by default).
- The ArgoCD server remains `ClusterIP`; the demo UI is accessed locally with `kubectl port-forward`, avoiding a public LoadBalancer and unnecessary AWS cost.
- The public repository `https://github.com/iDsniel/togglemaster-fase3.git` is monitored at revision `main` and path `gitops`.
- Automated synchronization uses `prune` and `selfHeal`.
- The ToggleMaster application deploys the five microservices managed by the `gitops/` Kustomization.

## Prerequisites

Gate 6 must be fully applied before ArgoCD starts synchronizing workloads:

1. Terraform workload IAM / EKS Pod Identity resources applied.
2. `togglemaster-runtime-secrets` present in namespace `togglemaster`.
3. PostgreSQL schemas initialized.

The installation script intentionally fails its preflight if the secret or workload Pod Identity associations are missing.

## Install

```bash
bash scripts/install-argocd.sh
```

## Evidence

```bash
bash scripts/argocd-evidence.sh
```

Expected state:

- ArgoCD pods Running/Ready.
- `togglemaster` Application: `Synced` and `Healthy`.
- Five ToggleMaster deployments available.
- Application source points to this repository, `main`, path `gitops`.
- Automated sync is enabled.

## UI access

Do not expose the ArgoCD server publicly for this lab. Use:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Then browse to `http://localhost:8080`.

Retrieve the initial admin password only when needed and never record or commit it.
