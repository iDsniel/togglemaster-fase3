provider "aws" {
  region = "us-east-1"

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
