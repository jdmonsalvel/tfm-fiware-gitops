terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }

  backend "s3" {
    # Valores inyectados en CI/CD via -backend-config o variables de entorno
    # bucket         = "tfm-fiware-tfstate-<account_id>"
    # key            = "prod/terraform.tfstate"
    # region         = "eu-west-1"
    # dynamodb_table = "tfm-fiware-tfstate-lock"
    # encrypt        = true
    # kms_key_id     = "alias/tfm-fiware-tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tfm-fiware-gitops"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "jdmonsalvel"
    }
  }
}
