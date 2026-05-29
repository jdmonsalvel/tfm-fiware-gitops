data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ──────────────────────────────────────────────────────────────────────────────
# ECR REPOSITORIES
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "repo" {
  for_each = var.ecr_repositories

  name                 = each.value.name
  image_tag_mutability = each.value.image_tag_mutability
  force_delete         = each.value.force_delete

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = each.value.encryption_type
    kms_key         = each.value.encryption_type == "KMS" ? each.value.kms_key_arn : null
  }

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# LIFECYCLE POLICIES
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_lifecycle_policy" "repo" {
  for_each = var.ecr_repositories

  repository = aws_ecr_repository.repo[each.key].name
  policy     = local.lifecycle_policies[each.key]
}

# ──────────────────────────────────────────────────────────────────────────────
# REPOSITORY POLICIES (cross-account access, CI/CD, EKS pull)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository_policy" "repo" {
  for_each = { for k, v in var.ecr_repositories : k => v if v.repository_policy != null }

  repository = aws_ecr_repository.repo[each.key].name
  policy     = each.value.repository_policy
}

# ──────────────────────────────────────────────────────────────────────────────
# REGISTRY SCANNING (continuo, nivel de cuenta)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_registry_scanning_configuration" "registry" {
  count = try(var.registry_scanning.enabled, false) ? 1 : 0

  scan_type = try(var.registry_scanning.scan_type, "ENHANCED")

  dynamic "rule" {
    for_each = length(try(var.registry_scanning.scan_filters, [])) > 0 ? var.registry_scanning.scan_filters : []
    content {
      scan_frequency = "CONTINUOUS_SCAN"
      repository_filter {
        filter      = rule.value.filter
        filter_type = rule.value.filter_type
      }
    }
  }

  # Si no hay filtros, escanea todos los repos
  dynamic "rule" {
    for_each = length(try(var.registry_scanning.scan_filters, [])) == 0 ? [1] : []
    content {
      scan_frequency = "CONTINUOUS_SCAN"
      repository_filter {
        filter      = "*"
        filter_type = "WILDCARD"
      }
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# REGISTRY REPLICATION (cross-region / cross-account)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_replication_configuration" "registry" {
  count = length(var.registry_replication) > 0 ? 1 : 0

  replication_configuration {
    dynamic "rule" {
      for_each = var.registry_replication
      content {
        destination {
          region      = rule.value.destination_region
          registry_id = rule.value.destination_account_id != null ? rule.value.destination_account_id : data.aws_caller_identity.current.account_id
        }

        dynamic "repository_filter" {
          for_each = length(rule.value.repository_filters) > 0 ? rule.value.repository_filters : []
          content {
            filter      = repository_filter.value.filter
            filter_type = repository_filter.value.filter_type
          }
        }
      }
    }
  }
}
