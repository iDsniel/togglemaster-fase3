# Gate 8 — Final Compliance, FinOps and Delivery Readiness

## Gate objective

Perform the final Phase 3 audit after the IaC, DevSecOps, GitOps and ArgoCD gates, consolidate the strongest evidence, prepare the AWS cost baseline, and identify only the remaining delivery-packaging tasks.

## Final technical state

### Infrastructure as Code

Live AWS validation confirms:

- EKS cluster `togglemaster-fase3`: `ACTIVE`, Kubernetes 1.35;
- managed node group: 3 desired `t3.small` On-Demand nodes, min 2 / max 4;
- 3 PostgreSQL RDS instances: `db.t4g.micro`, Single-AZ, 20 GiB gp3 each, private and available;
- ElastiCache Redis: `cache.t4g.micro`, available, encryption at rest enabled;
- DynamoDB analytics table: `PAY_PER_REQUEST`;
- SQS events queue with SQS-managed server-side encryption;
- 5 ECR repositories populated with commit-hash images;
- 1 NAT Gateway;
- Terraform state stored remotely in the S3 state bucket.

### CI / DevSecOps

The final `main` workflow after PR #5 completed successfully for commit:

`c557dece6a733a1789ce45740c1cc344d0c3a150`

The pipeline includes:

- language validation/build steps;
- lint/static validation;
- Semgrep SAST;
- Trivy filesystem SCA;
- Docker image build;
- Trivy container scan;
- GitHub OIDC authentication to AWS;
- ECR login and push using commit SHA tags;
- automated update of the GitOps desired-state image tags.

Historical failed runs are intentionally retained as evidence that the security gate blocked vulnerable code before remediation.

### GitOps / ArgoCD

The GitOps pipeline produced the automated commit:

`chore(gitops): deploy c557dece6a733a1789ce45740c1cc344d0c3a150 [skip ci]`

ArgoCD evidence confirms the `togglemaster` Application reached:

- **Sync Status: Synced**;
- **Application Health: Healthy**;
- **Last Sync: Sync OK**;
- automatic sync enabled;
- desired state tracked from `main/gitops`;
- all five microservices represented in the managed resource tree.

The ArgoCD event history also records the automatic transition sequence:

`Synced -> OutOfSync -> automated sync -> OutOfSync -> Synced -> Progressing -> Healthy`

This is the strongest evidence that deployment is driven by Git state rather than a manual `kubectl apply` workflow.

## ArgoCD evidence selected for the final report

### Evidence A — Primary screenshot

Use the full Application Tree screenshot showing simultaneously:

- `APP HEALTH: Healthy`;
- `SYNC STATUS: Synced to main`;
- `LAST SYNC: Sync OK`;
- `Auto sync is enabled`;
- GitHub Actions bot as the author of the GitOps commit;
- resource tree containing `analytics-service`, `auth-service`, `evaluation-service`, `flag-service`, and `targeting-service`.

This should be the principal ArgoCD screenshot in the PDF.

### Evidence B — Automatic synchronization history

Use the Events screenshot because it explicitly records:

- `Initiated automated sync`;
- successful sync operation;
- `OutOfSync -> Synced`;
- health transition to `Healthy`.

This is the best screenshot to prove automatic GitOps synchronization.

### Evidence C — Traceability from image to commit

Use the Application Summary screenshot showing:

- project and namespace;
- `Synced to main`;
- `Healthy`;
- all five ECR image references using the same commit-hash tag.

This is the best screenshot for end-to-end traceability: source commit -> ECR image -> GitOps -> ArgoCD.

### Screenshot not recommended as primary evidence

Do not use the screenshot with the manual **Synchronize** dialog as a principal report/video image. It is technically valid as a resource inventory view, but it can create ambiguity about whether the final deployment was manual. Prefer the Application Tree, Events, and Summary screenshots above.

## AWS cost baseline

See [`docs/aws-cost-estimate.md`](aws-cost-estimate.md).

Current estimated base cost for a 730-hour month is approximately **USD 210.22/month**, before usage-dependent network/request/logging costs.

The FIAP delivery still requires an AWS cost-estimate screenshot. The calculator screenshot should be captured using the validated live quantities documented in the cost estimate file.

## Final delivery checklist

The Phase 3 source requirements request:

- demonstration video up to 20 minutes;
- Terraform/IaC evidence;
- security failure followed by corrected passing pipeline;
- pipeline updating the GitOps image tag;
- ArgoCD automatically detecting and synchronizing the new version;
- Terraform source, workflow YAML and Kubernetes/GitOps manifests in the repository;
- final report containing participant names, documentation/video links, challenges/decisions, and AWS cost-estimate screenshot.

### Ready now

- IaC implementation and evidence;
- remote Terraform state;
- EKS/data platform/ECR;
- DevSecOps failure evidence;
- DevSecOps corrected green pipeline evidence;
- OIDC/ECR push evidence;
- automated GitOps tag update;
- ArgoCD automatic sync evidence;
- ArgoCD `Healthy / Synced` evidence;
- cost inventory and estimate inputs;
- technical challenges/decisions history.

### Remaining packaging work

1. Capture the AWS Pricing Calculator screenshot using the Gate 8 cost baseline.
2. Assemble the final report PDF with selected screenshots and concise technical narrative.
3. Assemble/edit the final <=20-minute demonstration video from the evidence already recorded.
4. Add the final documentation/video links to the delivery report.
5. After all evidence is safely captured, destroy/scale down the temporary AWS environment to stop ongoing charges.

## Gate 8 acceptance criteria

Gate 8 can be marked **DONE** when:

- the AWS Pricing Calculator screenshot is captured;
- the final report is generated;
- the final video is generated/uploaded and its link is available;
- the final compliance matrix has no unresolved mandatory item.