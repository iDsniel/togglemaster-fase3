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
