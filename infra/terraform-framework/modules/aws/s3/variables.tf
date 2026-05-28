variable "tags" {
  type    = map(string)
  default = {}
}

variable "s3_buckets" {
  type = map(object({
    name = string

    # Acceso y bloqueo público
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)

    # Versionado
    versioning = optional(bool, false)

    # Cifrado
    sse_algorithm      = optional(string, "aws:kms") # "aws:kms" | "AES256"
    kms_key_arn        = optional(string, null)      # null = CMK AWS managed (aws/s3)
    bucket_key_enabled = optional(bool, true)        # reduce costes KMS con S3 Bucket Keys

    # Control de acceso
    force_destroy = optional(bool, false)  # permite destroy con objetos dentro (usar en dev)
    acl           = optional(string, null) # null = deshabilitado (recomendado); "private" | "public-read"

    # CORS (para buckets que sirven assets desde navegadores)
    cors_rules = optional(list(object({
      allowed_headers = optional(list(string), ["*"])
      allowed_methods = list(string) # ["GET", "PUT", "POST", "DELETE", "HEAD"]
      allowed_origins = list(string)
      expose_headers  = optional(list(string), [])
      max_age_seconds = optional(number, 3600)
    })), [])

    # Lifecycle rules
    lifecycle_rules = optional(list(object({
      id      = string
      enabled = optional(bool, true)
      prefix  = optional(string, "") # "" = aplica a todo el bucket

      # Transiciones de clase de almacenamiento
      transitions = optional(list(object({
        days          = number
        storage_class = string # "STANDARD_IA" | "ONEZONE_IA" | "GLACIER" | "DEEP_ARCHIVE" | "INTELLIGENT_TIERING"
      })), [])

      # Transiciones de versiones no-current
      noncurrent_version_transitions = optional(list(object({
        noncurrent_days = number
        storage_class   = string
      })), [])

      # Expiración de objetos
      expiration_days = optional(number, null)

      # Expiración de versiones antiguas
      noncurrent_version_expiration_days = optional(number, null)

      # Eliminar marcadores de borrado de versiones (solo con versioning)
      abort_incomplete_multipart_upload_days = optional(number, 7)
    })), [])

    # Replicación (requiere versioning = true en origen y destino)
    replication = optional(object({
      role_arn                 = string # IAM role con permisos s3:ReplicateObject
      destination_bucket_arn   = string
      destination_region       = string
      storage_class            = optional(string, "STANDARD_IA")
      kms_key_arn              = optional(string, null) # CMK en la región destino
      replicate_delete_markers = optional(bool, false)
    }), null)

    # Notifications (para triggers Lambda/SQS/SNS)
    notifications = optional(object({
      queue_arn           = optional(string, null) # SQS
      queue_events        = optional(list(string), ["s3:ObjectCreated:*"])
      queue_filter_prefix = optional(string, "")
      queue_filter_suffix = optional(string, "")

      topic_arn    = optional(string, null) # SNS
      topic_events = optional(list(string), ["s3:ObjectCreated:*"])

      lambda_arn    = optional(string, null) # Lambda
      lambda_events = optional(list(string), ["s3:ObjectCreated:*"])
    }), null)

    # Website hosting estático
    website = optional(object({
      index_document = optional(string, "index.html")
      error_document = optional(string, "error.html")
    }), null)

    # Logging de accesos al bucket
    logging = optional(object({
      target_bucket = string # nombre del bucket de logs (debe existir)
      target_prefix = optional(string, "s3-access-logs/")
    }), null)

    # Object Lock (WORM — Write Once Read Many)
    object_lock = optional(object({
      enabled         = optional(bool, false)
      mode            = optional(string, "GOVERNANCE") # "GOVERNANCE" | "COMPLIANCE"
      retention_days  = optional(number, null)
      retention_years = optional(number, null)
    }), null)

    tags = optional(map(string), {})
  }))
  default = {}
}
