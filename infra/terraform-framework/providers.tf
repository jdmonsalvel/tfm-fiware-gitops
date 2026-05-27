locals {
  floci_endpoint = var.use_floci ? "http://localhost:4566" : null
}

provider "aws" {
  region     = var.use_floci ? "us-east-1" : var.region
  access_key = var.use_floci ? "test" : null
  secret_key = var.use_floci ? "test" : null

  skip_credentials_validation = var.use_floci
  skip_requesting_account_id  = var.use_floci
  skip_metadata_api_check     = var.use_floci

  dynamic "assume_role" {
    for_each = var.use_floci ? [] : [1]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/automate-cicd-role"
      session_name = "deployment_session_${var.environment}_${var.project}_${var.accountable}"
    }
  }

  dynamic "endpoints" {
    for_each = var.use_floci ? [1] : []
    content {
      acm            = local.floci_endpoint
      apigateway     = local.floci_endpoint
      apigatewayv2   = local.floci_endpoint
      autoscaling    = local.floci_endpoint
      cloudformation = local.floci_endpoint
      cloudfront     = local.floci_endpoint
      cloudwatch     = local.floci_endpoint
      cognitoidp     = local.floci_endpoint
      dynamodb       = local.floci_endpoint
      ec2            = local.floci_endpoint
      ecr            = local.floci_endpoint
      ecs            = local.floci_endpoint
      eks            = local.floci_endpoint
      elasticache    = local.floci_endpoint
      elb            = local.floci_endpoint
      elbv2          = local.floci_endpoint
      iam            = local.floci_endpoint
      kinesis        = local.floci_endpoint
      kms            = local.floci_endpoint
      lambda         = local.floci_endpoint
      rds            = local.floci_endpoint
      route53        = local.floci_endpoint
      s3             = local.floci_endpoint
      secretsmanager = local.floci_endpoint
      ses            = local.floci_endpoint
      sns            = local.floci_endpoint
      sqs            = local.floci_endpoint
      ssm            = local.floci_endpoint
      sts            = local.floci_endpoint
    }
  }
}