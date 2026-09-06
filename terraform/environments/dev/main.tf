module "networking" {
  source = "../../modules/networking"

  project_name = "togglemaster"
  environment  = "fase3"

  vpc_cidr = "10.30.0.0/16"

  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnet_cidrs = [
    "10.30.0.0/24",
    "10.30.1.0/24"
  ]

  private_subnet_cidrs = [
    "10.30.10.0/24",
    "10.30.11.0/24"
  ]
}
data "aws_caller_identity" "current" {}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = "togglemaster-fase3"
  kubernetes_version = "1.35"

  private_subnet_ids = module.networking.private_subnet_ids

  public_access_cidrs = [
    "177.97.183.119/32"
  ]

  admin_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/fiap-tc-deployer"

  node_instance_types = ["t3.small"]

  node_min_size     = 2
  node_desired_size = 3
  node_max_size     = 4
}
