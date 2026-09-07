# ToggleMaster — Tech Challenge Fase 3

## Objetivo

Evoluir a arquitetura aprovada na Fase 2 para uma plataforma
automatizada baseada em Infrastructure as Code, CI/CD, DevSecOps e GitOps.

## Matriz de requisitos

| ID | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| INF-01 | VPC | Terraform module networking | terraform plan/apply + AWS | DONE |
| INF-02 | Subnets públicas e privadas | Terraform | AWS + código | DONE |
| INF-03 | Internet Gateway | Terraform | AWS + código | DONE |
| INF-04 | Route Tables | Terraform | AWS + código | DONE |
| INF-05 | EKS | Terraform | AWS + kubectl | DONE |
| INF-06 | Node Groups | Terraform | AWS + kubectl | DONE |
| INF-07 | 3 RDS PostgreSQL | Terraform | AWS | DONE |
| INF-08 | ElastiCache Redis | Terraform | AWS | DONE |
| INF-09 | DynamoDB | Terraform | AWS | DONE |
| INF-10 | SQS | Terraform | AWS | DONE |
| INF-11 | 5 ECR | Terraform | AWS | DONE |
| INF-12 | Remote State S3 | Terraform Backend | S3 + terraform init/plan | DONE |
| CI-01 | Build | GitHub Actions matrix | Pipeline | DONE |
| CI-02 | Unit Tests / language validation | Go test/vet; Python validation for baseline without dedicated Python test suite | Pipeline | DONE |
| CI-03 | Lint / Static Analysis | Go vet + Ruff/Python validation | Pipeline | DONE |
| SEC-01 | SCA | Trivy filesystem | Pipeline | DONE |
| SEC-02 | SAST | Semgrep | Pipeline | DONE |
| SEC-03 | Critical security gate | GitHub Actions fails on critical findings | Historical Pipeline FAIL | DONE |
| SEC-04 | Container Scan | Trivy image | Pipeline | DONE |
| CI-04 | Docker Build | GitHub Actions | Pipeline | DONE |
| CI-05 | Push ECR | GitHub Actions + AWS OIDC | ECR | DONE |
| CI-06 | Commit hash image tag | GitHub Actions | ECR/GitOps | DONE |
| GITOPS-01 | GitOps manifests | `gitops/` Kustomize manifests | Repository | DONE |
| GITOPS-02 | ArgoCD | Helm on EKS | ArgoCD UI | DONE |
| GITOPS-03 | Automatic tag update | GitHub Actions | GitHub Actions bot GitOps commit | DONE |
| GITOPS-04 | Automatic sync | ArgoCD auto sync + prune + selfHeal | ArgoCD Events/UI | DONE |
| DEL-01 | Vulnerable build demonstration | Security findings retained in workflow history | Recorded evidence | EVIDENCE READY |
| DEL-02 | Fixed build demonstration | Final green CI on `main` | Recorded evidence | EVIDENCE READY |
| DEL-03 | Terraform demonstration | plan/apply/AWS state | Recorded evidence | EVIDENCE READY |
| DEL-04 | ArgoCD demonstration | Healthy/Synced tree + automated sync events | Recorded evidence | EVIDENCE READY |
| DEL-05 | AWS cost estimate | Validated live inventory + `docs/aws-cost-estimate.md` | AWS Calculator screenshot | SCREENSHOT PENDING |
| DEL-06 | Final report | Gate evidence + compliance audit | PDF/TXT | IN PROGRESS |

## Final delivery references

- Gate 8 audit: [`docs/gate8-final-audit.md`](gate8-final-audit.md)
- AWS cost baseline: [`docs/aws-cost-estimate.md`](aws-cost-estimate.md)

The technical implementation is complete. The remaining mandatory work is delivery packaging: AWS Pricing Calculator screenshot, final report, final demonstration video and final links.