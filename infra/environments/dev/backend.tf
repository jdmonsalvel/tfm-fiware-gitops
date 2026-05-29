terraform {
  backend "s3" {
    bucket         = "devops-101490102336-terraform-state-bucket"
    key            = "infra/dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
