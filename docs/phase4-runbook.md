# Fase 4 - Runbook e estado de entrega

Responsavel: Daniel Santos Costa, RM 373897, Discord danielsantos6494.
Data da auditoria: 01/11/2026. Base: fb069eae8784b4699d8395d3f36039be7fa70b78.
Branch local: feat/fase4-observability. Implantacao ainda nao autorizada.

## Auditoria

GitHub conectado com acesso de escrita. AWS conectada como root na conta 617309006489.
EKS ListClusters retornou vazio nas 17 regioes habilitadas consultadas.
DescribeCluster togglemaster-fase3 em us-east-1 retornou ResourceNotFoundException.
RDS, ElastiCache, ECR, NAT Gateway, SQS ToggleMaster e DynamoDB estavam ausentes
em us-east-1. Tags antigas nao comprovam existencia operacional.
O relatorio Gate 8 registra a entrega passada e nao deve ser apresentado como evidencia atual.
README herdado ainda aponta scripts ausentes da Fase 2.

## Implementacao preparada

Helm/Argo CD: kube-prometheus-stack 92.17.0, Loki 7.5.0, Collector 0.178.1.
Collectors contrib 0.163.2: gateway OTLP e DaemonSet para logs de containers.
Fluxo: aplicacoes -> OTLP -> gateway -> Prometheus (scrape), Loki (OTLP), Datadog.
Datadog connector produz estatisticas APM. Dashboard customizado inclui CPU,
memoria, requisicoes, erros e logs. Retencao de demonstracao: 3 dias.
Go e Python exportam sinais OTLP. Contexto HTTP atravessa chamadas concorrentes;
traceparent segue em atributos SQS para o consumidor analytics.
Logs stdout tambem sao coletados: evitar contar duplicatas como eventos de negocio.

Grafana provisiona alerta auth 5xx >5%, minimo de 20 requisicoes em 5 minutos,
persistencia de 2 minutos, PagerDuty, Discord e webhook autenticado do healer.
Sem dados e erros de consulta recebem estados distintos do alerta de negocio.

## Dependencias antes de implantar

1. Autorizar orçamento e janela de funcionamento da base AWS e observabilidade.
2. Revisar estado remoto Terraform, recursos remanescentes e plano de reconciliacao.
   Nao executar apply/destroy sem plano revisado. Atualizar CIDR administrativo fixo.
3. Usar identidade de deploy limitada em vez de root. Conferir versoes EKS/addons.
4. Restaurar EKS, banco de dados, cache, fila, tabela, ECR e imagens via CI.
5. Criar contas Datadog e PagerDuty com condicoes educacionais confirmadas.
6. Criar servidor/canal Discord e webhook, com autorizacao para mensagens de teste.
7. Criar secrets sem valores no Git: observability-integrations em observability
   (datadog-api-key, pagerduty-routing-key, discord-webhook, healer-token),
   grafana-admin (username/password), self-healer-auth em togglemaster (token igual
   ao healer-token) e togglemaster-service-api-key (api-key valida criada no auth).
8. Configurar StorageClass EBS CSI e permissao para PVCs, NetworkPolicy enforcement
   e capacidade de nodes. A base t3.small precisa de avaliacao de memoria/pods.
9. Publicar a branch revisada antes de sincronizar Applications. Apps de observabilidade
   estao em sync manual para impedir custos antes da autorizacao.

## Self-healing

Desativado por padrao. Recebe apenas alertas firing recentes do auth com labels
esperados. Token >=32 caracteres, alvo fixo e nenhuma execucao de comandos.
Ledger SQLite em PVC reserva uma tentativa antes da alteracao. Cooldown 15 minutos;
uma tentativa por incidente, inclusive em falha. Verifica resourceVersion e rollout;
aguarda ate 180 segundos. RBAC limita get/patch ao deployment auth-service.
RBAC Kubernetes nao restringe campos do patch: em producao adicionar admission policy.
NetworkPolicy permite entrada apenas do Grafana; depende de enforcement no cluster.
Argo ignora somente a annotation recovery-id para nao desfazer a mitigacao.

Ativar somente em ambiente de demonstracao aprovado: annotation de metadata
togglemaster.io/self-heal=enabled no auth e HEALING_ENABLED=true no healer, via Git.
Rollback: desativar HEALING_ENABLED e remover opt-in; revisar incidente manualmente.
Nao parar RDS ou apagar recursos para demonstrar recuperacao.

## Validacao pendente e evidencia real

Charts renderizados e manifests Kustomize gerados localmente. Go compilou e testes
de seguranca do healer passaram. Validacao runtime do Collector, provisionamento
Grafana, consultas PromQL, imagens e tracing ponta a ponta ainda sao obrigatorios.
Realizar carga com cache miss e chave valida; verificar evaluation -> flag/targeting
-> auth e SQS -> analytics no APM. Confirmar os cinco servicos no Service Map.
Testar alerta com falha temporaria controlada e reversivel; provar Firing, incidente,
mensagem Discord, tentativa do healer e recuperacao. Confirmar fechamento do incidente.
Capturar timestamps, IDs e prints reais. Nenhuma evidencia de producao foi fabricada.

## Roteiro do video (ate 25 minutos)

0-4: Terraform, CI DevSecOps, EKS e Argo Synced/Healthy.
4-9: dashboard, metricas e consulta Loki; explicar roteamento OTel.
9-14: requisicao real, trace distribuido e Service Map.
14-22: falha aprovada, alerta, PagerDuty, Discord, automacao e recuperacao.
22-25: decisoes, limites, evidencias e encerramento.

Relatorio PDF final depende dos prints reais, URL do video e URL do codigo publicado.
Deve conter os dados do participante acima, arquitetura, justificativas e quatro prints
obrigatorios: Grafana, trace, Discord e execucao do healer.
