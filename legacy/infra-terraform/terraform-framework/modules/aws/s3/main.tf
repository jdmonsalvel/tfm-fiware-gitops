# ──────────────────────────────────────────────────────────────────────────────
# BUCKET
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "bucket" {
  for_each = var.s3_buckets

  bucket        = each.value.name
  force_destroy = each.value.force_destroy

  dynamic "object_lock_configuration" {
    for_each = each.value.object_lock != null && each.value.object_lock.enabled ? [each.value.object_lock] : []
    content {
      object_lock_enabled = "Enabled"
    }
  }

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })
}

# ──────────────────────────────────────────────────────────────────────────────
# BLOQUEO DE ACCESO PÚBLICO (recomendado en todos los buckets privados)
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "bucket" {
  for_each = var.s3_buckets

  bucket                  = aws_s3_bucket.bucket[each.key].id
  block_public_acls       = each.value.block_public_acls
  block_public_policy     = each.value.block_public_policy
  ignore_public_acls      = each.value.ignore_public_acls
  restrict_public_buckets = each.value.restrict_public_buckets
}

# ──────────────────────────────────────────────────────────────────────────────
# CIFRADO SSE
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  for_each = var.s3_buckets

  bucket = aws_s3_bucket.bucket[each.key].id

  rule {
    bucket_key_enabled = each.value.sse_algorithm == "aws:kms" ? each.value.bucket_key_enabled : false

    apply_server_side_encryption_by_default {
      sse_algorithm     = each.value.sse_algorithm
      kms_master_key_id = each.value.sse_algorithm == "aws:kms" ? each.value.kms_key_arn : null
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# VERSIONADO
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "bucket" {
  for_each = var.s3_buckets

  bucket = aws_s3_bucket.bucket[each.key].id

  versioning_configuration {
    status = each.value.versioning || each.value.replication != null ? "Enabled" : "Suspended"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# LIFECYCLE RULES
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  for_each = { for k, v in var.s3_buckets : k => v if length(v.lifecycle_rules) > 0 }

  bucket = aws_s3_bucket.bucket[each.key].id

  dynamic "rule" {
    for_each = each.value.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [rule.value.abort_incomplete_multipart_upload_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.bucket]
}

# ──────────────────────────────────────────────────────────────────────────────
# CORS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_cors_configuration" "bucket" {
  for_each = local.cors_buckets

  bucket = aws_s3_bucket.bucket[each.key].id

  dynamic "cors_rule" {
    for_each = each.value.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# WEBSITE ESTÁTICO
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_website_configuration" "bucket" {
  for_each = local.website_buckets

  bucket = aws_s3_bucket.bucket[each.key].id

  index_document { suffix = each.value.website.index_document }
  error_document { key = each.value.website.error_document }
}

# ──────────────────────────────────────────────────────────────────────────────
# SERVER ACCESS LOGGING
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_logging" "bucket" {
  for_each = local.logging_buckets

  bucket        = aws_s3_bucket.bucket[each.key].id
  target_bucket = each.value.logging.target_bucket
  target_prefix = each.value.logging.target_prefix
}

# ──────────────────────────────────────────────────────────────────────────────
# REPLICACIÓN CROSS-REGION
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_replication_configuration" "bucket" {
  for_each = local.replicated_buckets

  role   = each.value.replication.role_arn
  bucket = aws_s3_bucket.bucket[each.key].id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = each.value.replication.destination_bucket_arn
      storage_class = each.value.replication.storage_class

      dynamic "encryption_configuration" {
        for_each = each.value.replication.kms_key_arn != null ? [1] : []
        content {
          replica_kms_key_id = each.value.replication.kms_key_arn
        }
      }

      dynamic "replication_time" {
        for_each = [1]
        content {
          status = "Enabled"
          time { minutes = 15 }
        }
      }

      dynamic "metrics" {
        for_each = [1]
        content {
          status = "Enabled"
          event_threshold { minutes = 15 }
        }
      }
    }

    dynamic "delete_marker_replication" {
      for_each = each.value.replication.replicate_delete_markers ? [1] : []
      content {
        status = "Enabled"
      }
    }

    source_selection_criteria {
      dynamic "sse_kms_encrypted_objects" {
        for_each = each.value.replication.kms_key_arn != null ? [1] : []
        content {
          status = "Enabled"
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.bucket]
}

# ──────────────────────────────────────────────────────────────────────────────
# EVENT NOTIFICATIONS
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_notification" "bucket" {
  for_each = { for k, v in var.s3_buckets : k => v if v.notifications != null }

  bucket = aws_s3_bucket.bucket[each.key].id

  dynamic "queue" {
    for_each = each.value.notifications.queue_arn != null ? [1] : []
    content {
      queue_arn     = each.value.notifications.queue_arn
      events        = each.value.notifications.queue_events
      filter_prefix = each.value.notifications.queue_filter_prefix
      filter_suffix = each.value.notifications.queue_filter_suffix
    }
  }

  dynamic "topic" {
    for_each = each.value.notifications.topic_arn != null ? [1] : []
    content {
      topic_arn = each.value.notifications.topic_arn
      events    = each.value.notifications.topic_events
    }
  }

  dynamic "lambda_function" {
    for_each = each.value.notifications.lambda_arn != null ? [1] : []
    content {
      lambda_function_arn = each.value.notifications.lambda_arn
      events              = each.value.notifications.lambda_events
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# OBJECT LOCK (WORM) — Configuración de retención por defecto
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_object_lock_configuration" "bucket" {
  for_each = local.object_lock_buckets

  bucket = aws_s3_bucket.bucket[each.key].id

  rule {
    default_retention {
      mode  = each.value.object_lock.mode
      days  = each.value.object_lock.retention_days
      years = each.value.object_lock.retention_years
    }
  }

  depends_on = [aws_s3_bucket_versioning.bucket]
}
