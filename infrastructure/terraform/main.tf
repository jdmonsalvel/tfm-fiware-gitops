module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size
}

resource "aws_secretsmanager_secret" "orion_mongo_uri" {
  name                    = "/${var.project_name}/${var.environment}/orion/mongo-uri"
  description             = "MongoDB connection URI for Orion-LD Context Broker"
  recovery_window_in_days = 0

  tags = {
    Component = "orion-ld"
  }
}

resource "aws_secretsmanager_secret" "keyrock_db_password" {
  name                    = "/${var.project_name}/${var.environment}/keyrock/db-password"
  description             = "MySQL password for Keyrock Identity Manager"
  recovery_window_in_days = 0

  tags = {
    Component = "keyrock"
  }
}

resource "aws_secretsmanager_secret" "keyrock_admin_password" {
  name                    = "/${var.project_name}/${var.environment}/keyrock/admin-password"
  description             = "Keyrock admin user password"
  recovery_window_in_days = 0

  tags = {
    Component = "keyrock"
  }
}

resource "aws_iam_policy" "external_secrets" {
  name        = "${var.project_name}-${var.environment}-external-secrets"
  description = "Allows External Secrets Operator to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:/${var.project_name}/${var.environment}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "external_secrets" {
  name        = "${var.project_name}-${var.environment}-external-secrets-irsa"
  description = "IRSA role for External Secrets Operator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:platform:external-secrets"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
