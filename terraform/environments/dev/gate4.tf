module "data_platform" {
  source = "../../modules/data-platform"

  project_name = "togglemaster-fase3"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  private_subnet_cidrs = [
    "10.30.10.0/24",
    "10.30.11.0/24"
  ]
}

output "rds_endpoints" {
  value = module.data_platform.rds_endpoints
}

output "rds_secret_arns" {
  value = module.data_platform.rds_secret_arns
}

output "redis_endpoint" {
  value = module.data_platform.redis_endpoint
}

output "sqs_url" {
  value = module.data_platform.sqs_url
}

output "dynamodb_table" {
  value = module.data_platform.dynamodb_table
}

output "ecr_repository_urls" {
  value = module.data_platform.ecr_repository_urls
}
