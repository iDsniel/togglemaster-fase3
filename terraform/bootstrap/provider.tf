provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ToggleMaster"
      Phase       = "3"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Course      = "FIAP-POSTECH"
    }
  }
}
