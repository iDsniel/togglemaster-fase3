# Fase 4 - plano de custos ate a entrega

Atualizacao autorizada: a data 16/11/2026 deixa de definir tempo de funcionamento. Ativar AWS somente apos testes locais e integracoes prontas; encerrar recursos do projeto depois da entrega e preservacao das evidencias. Teto total: US$ 50, sem depender dos creditos.

## Cenario de referencia em us-east-1

Precos consultados em 01/11/2026 na API AWS Pricing, exceto EKS (pagina oficial):
- EKS standard: US$ 0,10/h.
- 3 nodes t3.medium Linux On-Demand: US$ 0,0416/h cada.
- 3 RDS PostgreSQL db.t4g.micro Single-AZ: US$ 0,016/h cada.
- Redis cache.t4g.micro, versao em suporte regular: US$ 0,016/h.
- Subtotal computacao: US$ 0.2888/h.

Janela de 24h: US$ 6.93 de computacao.
Janela de 48h: US$ 13.86 de computacao.
Provisao inicial para armazenamento, rede, IPv4, logs e requisicoes: US$ 10,00 (margem de planejamento, ainda nao uma cotacao detalhada).
Referencia para 48h com essa provisao: US$ 23.86.
Reserva adicional de seguranca: US$ 10,00 dentro do teto; reavaliar antes de US$ 40.

## Execucao economica

1. Concluir codigo, testes locais, contas externas e roteiro antes de iniciar cobranca AWS.
2. Provisionar uma unica vez para teste integrado, correcao e gravacao; meta de 24h, planejamento de ate 48h.
3. Reaproveitar Terraform e arquitetura cumulativa. Avaliar nodes por capacidade real, nao reduzir memoria a ponto de impedir observabilidade.
4. Evitar NAT Gateway e balanceadores adicionais quando tecnicamente viavel; acesso a dashboards por port-forward. Nao alterar rede sem validar dependencias e seguranca.
5. Retencao curta e telemetria limitada. Usar apenas planos externos gratuitos/educacionais confirmados.
6. Capturar e verificar video, prints, logs, codigo e relatorio antes de encerrar.
7. A autorizacao do usuario inclui o encerramento dos recursos exclusivos do projeto depois de concluir todas as etapas. Revisar plano de destruicao, preservar entregaveis e nao tocar outros projetos.
8. Verificar custos residuais: EKS, EC2, NAT, LB, EBS/PVC, snapshots, IPs, RDS, Redis, ECR e armazenamento. Apenas parar EC2 nao elimina todas as cobrancas.

Os US$ 96,11 de creditos informados pela AWS nao ampliam o limite e dependem de elegibilidade e validade. AWS Budgets nao e bloqueio rigido. A estimativa final deve incluir todos os recursos do plano Terraform e tempo de provisionamento/desmontagem.

Fontes: AWS Pricing GetProducts (AmazonEC2, AmazonRDS, AmazonElastiCache); https://aws.amazon.com/eks/pricing/
