locals {
  # Repos con lifecycle policy configurada (incluye todos — siempre generamos política mínima)
  repos_with_lifecycle = var.ecr_repositories

  # Genera las reglas de lifecycle para cada repositorio
  lifecycle_policies = {
    for k, repo in var.ecr_repositories : k => jsonencode({
      rules = compact(flatten([
        # Regla 1: mantener solo N imágenes tagged (si se especifica)
        repo.lifecycle_policy != null && repo.lifecycle_policy.max_tagged_image_count != null ? [{
          rulePriority = 1
          description  = "Mantener máximo ${repo.lifecycle_policy.max_tagged_image_count} imágenes tagged"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["v", "release", "prod", "staging", "latest"]
            countType     = "imageCountMoreThan"
            countNumber   = repo.lifecycle_policy.max_tagged_image_count
          }
          action = { type = "expire" }
        }] : [],

        # Regla 2: expirar imágenes untagged después de N días
        repo.lifecycle_policy != null ? [{
          rulePriority = 10
          description  = "Expirar imágenes sin tag después de ${try(repo.lifecycle_policy.max_untagged_image_age_days, 7)} días"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = try(repo.lifecycle_policy.max_untagged_image_age_days, 7)
          }
          action = { type = "expire" }
          }] : [{
          rulePriority = 10
          description  = "Expirar imágenes sin tag después de 7 días (default)"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 7
          }
          action = { type = "expire" }
        }]
      ]))
    })
  }
}
