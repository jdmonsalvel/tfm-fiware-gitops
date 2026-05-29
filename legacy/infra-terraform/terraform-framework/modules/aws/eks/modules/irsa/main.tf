locals {
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_id  = trimprefix(var.oidc_issuer_url, "https://")
}

# ──────────────────────────────────────────────────────────────────────────────
# AWS LOAD BALANCER CONTROLLER
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_aws_lb_controller" {
  count = try(var.addons.aws_load_balancer_controller, true) ? 1 : 0
  name  = "${var.cluster_name}-irsa-aws-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-aws-lb-controller" })
}

resource "aws_iam_policy" "aws_lb_controller" {
  count = try(var.addons.aws_load_balancer_controller, true) ? 1 : 0
  name  = "${var.cluster_name}-aws-lb-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["iam:CreateServiceLinkedRole"]
        Resource  = "*"
        Condition = { StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" } }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways", "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools", "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes", "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates", "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules", "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes", "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags", "elasticloadbalancing:DescribeTrustStores",
          "cognito-idp:DescribeUserPoolClient", "acm:ListCertificates", "acm:DescribeCertificate",
          "iam:ListServerCertificates", "iam:GetServerCertificate",
          "waf-regional:GetWebACL", "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL", "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL", "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState", "shield:DescribeProtection",
          "shield:CreateProtection", "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect    = "Allow"
        Action    = ["ec2:CreateTags"]
        Resource  = "arn:aws:ec2:*:*:security-group/*"
        Condition = { StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" } }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-aws-lb-controller-policy" })
}

resource "aws_iam_role_policy_attachment" "irsa_aws_lb_controller" {
  count      = try(var.addons.aws_load_balancer_controller, true) ? 1 : 0
  role       = aws_iam_role.irsa_aws_lb_controller[0].name
  policy_arn = aws_iam_policy.aws_lb_controller[0].arn
}

# ──────────────────────────────────────────────────────────────────────────────
# EXTERNAL SECRETS OPERATOR
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_external_secrets" {
  count = try(var.addons.external_secrets, true) ? 1 : 0
  name  = "${var.cluster_name}-irsa-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:external-secrets:external-secrets"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-external-secrets" })
}

resource "aws_iam_role_policy" "irsa_external_secrets" {
  count = try(var.addons.external_secrets, true) ? 1 : 0
  name  = "external-secrets-access"
  role  = aws_iam_role.irsa_external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecrets"]
        Resource = ["arn:aws:secretsmanager:*:*:secret:*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:DescribeParameters"]
        Resource = ["arn:aws:ssm:*:*:parameter/*"]
      }
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# CERT MANAGER
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_cert_manager" {
  count = try(var.addons.cert_manager, true) ? 1 : 0
  name  = "${var.cluster_name}-irsa-cert-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:cert-manager:cert-manager"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-cert-manager" })
}

resource "aws_iam_role_policy" "irsa_cert_manager" {
  count = try(var.addons.cert_manager, true) ? 1 : 0
  name  = "cert-manager-route53"
  role  = aws_iam_role.irsa_cert_manager[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:GetChange"]
        Resource = ["arn:aws:route53:::change/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZonesByName"]
        Resource = ["*"]
      }
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# EXTERNAL DNS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_external_dns" {
  count = try(var.addons.external_dns, false) ? 1 : 0
  name  = "${var.cluster_name}-irsa-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:kube-system:external-dns"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-external-dns" })
}

resource "aws_iam_role_policy" "irsa_external_dns" {
  count = try(var.addons.external_dns, false) ? 1 : 0
  name  = "external-dns-route53"
  role  = aws_iam_role.irsa_external_dns[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResource"]
        Resource = ["*"]
      }
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# EBS CSI DRIVER
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_ebs_csi" {
  count = try(var.addons.ebs_csi, true) ? 1 : 0
  name  = "${var.cluster_name}-irsa-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-ebs-csi" })
}

resource "aws_iam_role_policy_attachment" "irsa_ebs_csi" {
  count      = try(var.addons.ebs_csi, true) ? 1 : 0
  role       = aws_iam_role.irsa_ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ──────────────────────────────────────────────────────────────────────────────
# VELERO
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_velero" {
  count = try(var.addons.velero, false) ? 1 : 0
  name  = "${var.cluster_name}-irsa-velero"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:velero:velero-server"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-velero" })
}

resource "aws_iam_role_policy" "irsa_velero" {
  count = try(var.addons.velero, false) ? 1 : 0
  name  = "velero-s3"
  role  = aws_iam_role.irsa_velero[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSnapshots", "ec2:CreateTags", "ec2:DeleteSnapshot", "ec2:DescribeSnapshots", "ec2:DescribeVolumes"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "s3:AbortMultipartUpload"]
        Resource = ["arn:aws:s3:::velero-*", "arn:aws:s3:::velero-*/*"]
      }
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# MONITORING (Loki + Prometheus — acceso a S3)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_monitoring" {
  count = try(var.addons.monitoring, false) ? 1 : 0
  name  = "${var.cluster_name}-irsa-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
        }
        StringLike = {
          "${local.oidc_provider_id}:sub" = [
            "system:serviceaccount:monitoring:loki",
            "system:serviceaccount:monitoring:prometheus*"
          ]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-monitoring" })
}

resource "aws_iam_role_policy" "irsa_monitoring" {
  count = try(var.addons.monitoring, false) ? 1 : 0
  name  = "monitoring-s3"
  role  = aws_iam_role.irsa_monitoring[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject", "s3:GetObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:AbortMultipartUpload"
      ]
      Resource = var.monitoring_bucket_arn != "" ? [
        var.monitoring_bucket_arn,
        "${var.monitoring_bucket_arn}/*"
      ] : ["arn:aws:s3:::*"]
    }]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# KARPENTER IRSA (controller)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "irsa_karpenter" {
  count = var.karpenter_enabled ? 1 : 0
  name  = "${var.cluster_name}-irsa-karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_id}:aud" = ["sts.amazonaws.com"]
          "${local.oidc_provider_id}:sub" = ["system:serviceaccount:karpenter:karpenter"]
        }
      }
    }]
  })
  tags = merge(var.tags, { Name = "${var.cluster_name}-irsa-karpenter" })
}

resource "aws_iam_role_policy" "irsa_karpenter" {
  count = var.karpenter_enabled ? 1 : 0
  name  = "karpenter-controller"
  role  = aws_iam_role.irsa_karpenter[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances", "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates", "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings", "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups", "ec2:DescribeImages",
          "ec2:DescribeSpotPriceHistory", "ec2:TerminateInstances", "ec2:CreateTags"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "AllowScopedIAMActions"
        Effect = "Allow"
        Action = [
          "iam:PassRole", "iam:CreateInstanceProfile", "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile", "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile", "iam:TagInstanceProfile"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "AllowSQS"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl",
          "sqs:ReceiveMessage", "sqs:SendMessage"
        ]
        Resource = var.karpenter_queue_arn != "" ? [var.karpenter_queue_arn] : ["*"]
      },
      {
        Sid    = "AllowSSM"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          "arn:aws:ssm:*::parameter/aws/service/eks/optimized-ami/*",
          "arn:aws:ssm:*::parameter/aws/service/bottlerocket/*"
        ]
      }
    ]
  })
}
