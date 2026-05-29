provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = [1]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/automate-cicd-role"
      session_name = "deployment_session_${var.environment}_${var.project}_${var.accountable}"
    }
  }
}
