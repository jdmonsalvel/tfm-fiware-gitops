locals {
  # Buckets con replicación habilitada (requieren versioning obligatorio)
  replicated_buckets = {
    for k, v in var.s3_buckets : k => v if v.replication != null
  }

  # Buckets con CORS configurado
  cors_buckets = {
    for k, v in var.s3_buckets : k => v if length(v.cors_rules) > 0
  }

  # Buckets con logging configurado
  logging_buckets = {
    for k, v in var.s3_buckets : k => v if v.logging != null
  }

  # Buckets con website estático
  website_buckets = {
    for k, v in var.s3_buckets : k => v if v.website != null
  }

  # Buckets con Object Lock
  object_lock_buckets = {
    for k, v in var.s3_buckets : k => v if v.object_lock != null && v.object_lock.enabled
  }

  # Aplanar lifecycle rules: { "bucket_key-rule_id" => {...} }
  lifecycle_rules = flatten([
    for bucket_key, bucket in var.s3_buckets : [
      for rule in bucket.lifecycle_rules : {
        key        = "${bucket_key}-${rule.id}"
        bucket_key = bucket_key
        rule       = rule
      }
    ]
  ])

  # Aplanar CORS rules: { "bucket_key-index" => {...} }
  cors_rules = flatten([
    for bucket_key, bucket in var.s3_buckets : [
      for idx, rule in bucket.cors_rules : {
        key        = "${bucket_key}-${idx}"
        bucket_key = bucket_key
        rule       = rule
      }
    ]
  ])
}
