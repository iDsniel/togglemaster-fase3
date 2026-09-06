# ToggleMaster - Tech Challenge Fase 2

Este kit foi montado para acelerar a entrega da Fase 2. Ele nao substitui os repositorios oficiais; ele adiciona Dockerfiles, docker-compose, manifests Kubernetes, scripts e documentacao de apoio.

## Ordem de execucao urgente

### 1. Preparar Ubuntu/WSL
```bash
cd ~/Downloads/togglemaster-fase2-kit
./scripts/01-install-tools-ubuntu24.sh
```
Feche e reabra o Ubuntu se o Docker pedir permissao de grupo.

### 2. Clonar repositorios e aplicar Dockerfiles
```bash
cd ~/Downloads/togglemaster-fase2-kit
./scripts/02-clone-and-prepare.sh
```

### 3. Validar localmente com Docker Compose
```bash
./scripts/03-run-local.sh
./scripts/04-test-local.sh
```
Evidencia para o video: `docker compose ps` mostrando 9 containers e os endpoints `/health`.

### 4. AWS - login e ECR
```bash
aws configure
export AWS_REGION=us-east-1
./scripts/10-aws-login-check.sh
./scripts/20-create-ecr.sh
./scripts/21-build-push-ecr.sh
```

### 5. AWS - EKS
```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=togglemaster-fase2
./scripts/30-create-eks.sh
./scripts/31-install-addons.sh
```

### 6. AWS - SQS e DynamoDB
```bash
./scripts/40-create-sqs-dynamodb.sh
```

### 7. AWS - RDS e ElastiCache
Siga o arquivo `aws/PASSO_A_PASSO_AWS_MANUAL.md`. Estes recursos dependem de VPC, subnets e Security Groups criados pelo EKS.

### 8. Kubernetes - Secrets e deploy
Preencha as variaveis reais e gere o Secret:
```bash
export MASTER_KEY='admin-secreto-123'
export AUTH_DATABASE_URL='postgres://USER:SENHA@AUTH_RDS_ENDPOINT:5432/auth_db?sslmode=require'
export FLAG_DATABASE_URL='postgres://USER:SENHA@FLAG_RDS_ENDPOINT:5432/flag_db?sslmode=require'
export TARGETING_DATABASE_URL='postgres://USER:SENHA@TARGETING_RDS_ENDPOINT:5432/targeting_db?sslmode=require'
export REDIS_URL='redis://ELASTICACHE_ENDPOINT:6379'
export AWS_SQS_URL='https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/togglemaster-analytics-events'
./scripts/50-generate-secret.sh > k8s/20-secret/secret.generated.yaml
./scripts/60-render-k8s-images.sh
./scripts/61-apply-k8s.sh
```

### 9. Testes finais
```bash
LB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
./scripts/70-test-k8s.sh "$LB"
kubectl get hpa -n togglemaster
kubectl get pods -n togglemaster
```

Para carga:
```bash
kubectl get hpa -n togglemaster -w
# em outro terminal
./scripts/71-load-test-evaluation.sh "$LB"
```

Para SQS/DynamoDB:
```bash
export AWS_SQS_URL='URL_REAL_DA_FILA'
./scripts/72-send-sqs-messages.sh 100
kubectl logs -n togglemaster deploy/analytics-service --tail=100
aws dynamodb scan --table-name ToggleMasterAnalytics --region us-east-1 --limit 5
```
