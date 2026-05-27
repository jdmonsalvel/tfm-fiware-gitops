provider "aws" {
  region = var.cluster_region

  dynamic "assume_role" {
    for_each = var.assume_role_arn != "" ? [1] : []
    content {
      role_arn = var.assume_role_arn
    }
  }
}

# Usa exec con aws eks get-token para evitar tokens de 15 min expirados
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.cluster_region],
        var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : []
      )
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.cluster_region],
      var.assume_role_arn != "" ? ["--role-arn", var.assume_role_arn] : []
    )
  }
}
