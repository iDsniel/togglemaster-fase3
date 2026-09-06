variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

locals {
  databases = {
    auth = {
      identifier = "${var.project_name}-auth-db"
      db_name    = "authdb"
    }
    flag = {
      identifier = "${var.project_name}-flag-db"
      db_name    = "flagdb"
    }
    targeting = {
      identifier = "${var.project_name}-targeting-db"
      db_name    = "targetingdb"
    }
  }

  services = toset([
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service"
  ])
}

# ============================================================
# RDS - private PostgreSQL instances
# ============================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "PostgreSQL access from private EKS subnets"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from private EKS subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_db_instance" "postgres" {
  for_each = local.databases

  identifier = each.value.identifier
  db_name    = each.value.db_name

  engine         = "postgres"
  engine_version = "16.15"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  username                    = "togglemaster"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible    = false
  multi_az               = false
  backup_retention_period = 1

  auto_minor_version_upgrade = true
  apply_immediately           = true

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = each.value.identifier
  }
}

# ============================================================
# ElastiCache Redis
# ============================================================

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Redis access from private EKS subnets"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from private EKS subnets"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  tags = {
    Name = "${var.project_name}-redis-sg"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-redis"
  description          = "ToggleMaster Redis cache"

  engine         = "redis"
  engine_version = "7.1"

  node_type          = "cache.t4g.micro"
  num_cache_clusters = 1
  port               = 6379

  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = false
  multi_az_enabled            = false
  at_rest_encryption_enabled  = true
  apply_immediately           = true

  tags = {
    Name = "${var.project_name}-redis"
  }
}

# ============================================================
# DynamoDB
# ============================================================

resource "aws_dynamodb_table" "analytics" {
  name         = "${var.project_name}-analytics-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-analytics-events"
  }
}

# ============================================================
# SQS
# ============================================================

resource "aws_sqs_queue" "events" {
  name = "${var.project_name}-events"

  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400

  sqs_managed_sse_enabled = true

  tags = {
    Name = "${var.project_name}-events"
  }
}

# ============================================================
# ECR
# ============================================================

resource "aws_ecr_repository" "services" {
  for_each = local.services

  name                 = "togglemaster/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Service = each.value
  }
}

# ============================================================
# Outputs
# ============================================================

output "rds_endpoints" {
  value = {
    for name, db in aws_db_instance.postgres :
    name => "${db.address}:${db.port}"
  }
}

output "rds_secret_arns" {
  value = {
    for name, db in aws_db_instance.postgres :
    name => db.master_user_secret[0].secret_arn
  }
}

output "redis_endpoint" {
  value = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
}

output "sqs_url" {
  value = aws_sqs_queue.events.url
}

output "dynamodb_table" {
  value = aws_dynamodb_table.analytics.name
}

output "ecr_repository_urls" {
  value = {
    for name, repo in aws_ecr_repository.services :
    name => repo.repository_url
  }
}
