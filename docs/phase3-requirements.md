# ToggleMaster — Tech Challenge Fase 3

## Objetivo

Evoluir a arquitetura aprovada na Fase 2 para uma plataforma
automatizada baseada em Infrastructure as Code, CI/CD, DevSecOps e GitOps.

## Matriz de requisitos

| ID | Requisito | Implementação | Evidência | Status |
|---|---|---|---|---|
| INF-01 | VPC | Terraform module networking | terraform plan/apply + AWS | TODO |
| INF-02 | Subnets públicas e privadas | Terraform | AWS + código | TODO |
| INF-03 | Internet Gateway | Terraform | AWS + código | TODO |
| INF-04 | Route Tables | Terraform | AWS + código | TODO |
| INF-05 | EKS | Terraform | AWS + kubectl | TODO |
| INF-06 | Node Groups | Terraform | AWS + kubectl | TODO |
| INF-07 | 3 RDS PostgreSQL | Terraform | AWS | TODO |
| INF-08 | ElastiCache Redis | Terraform | AWS | TODO |
| INF-09 | DynamoDB | Terraform | AWS | TODO |
| INF-10 | SQS | Terraform | AWS | TODO |
| INF-11 | 5 ECR | Terraform | AWS | TODO |
| INF-12 | Remote State S3 | Terraform Backend | S3 + terraform init | TODO |
| CI-01 | Build | GitHub Actions | Pipeline | TODO |
| CI-02 | Unit Tests | GitHub Actions | Pipeline | TODO |
| CI-03 | Lint | GitHub Actions | Pipeline | TODO |
| SEC-01 | SCA | Trivy filesystem | Pipeline | TODO |
| SEC-02 | SAST | gosec/bandit | Pipeline | TODO |
| SEC-03 | Critical security gate | GitHub Actions | Pipeline FAIL | TODO |
| SEC-04 | Container Scan | Trivy image | Pipeline | TODO |
| CI-04 | Docker Build | GitHub Actions | Pipeline | TODO |
| CI-05 | Push ECR | GitHub Actions | ECR | TODO |
| CI-06 | Commit hash image tag | GitHub Actions | ECR/GitOps | TODO |
| GITOPS-01 | GitOps manifests | Git repository | Repository | TODO |
| GITOPS-02 | ArgoCD | EKS | ArgoCD UI | TODO |
| GITOPS-03 | Automatic tag update | GitHub Actions | Git commit | TODO |
| GITOPS-04 | Automatic sync | ArgoCD | ArgoCD UI | TODO |
| DEL-01 | Vulnerable build demonstration | Pipeline | Video | TODO |
| DEL-02 | Fixed build demonstration | Pipeline | Video | TODO |
| DEL-03 | Terraform demonstration | Terraform | Video | TODO |
| DEL-04 | ArgoCD demonstration | ArgoCD | Video | TODO |
| DEL-05 | AWS cost estimate | AWS Calculator | Screenshot | TODO |
| DEL-06 | Final report | Documentation | PDF/TXT | TODO |
