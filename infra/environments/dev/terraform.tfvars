terraform_framework_version = "v1.0.0"

# account_id se inyecta como TF_VAR_account_id desde GitHub Secret
region      = "eu-west-1"
project     = "tfm-fiware-gitops"
environment = "dev"
accountable = "jdmonsalvel"

# ─── Red ──────────────────────────────────────────────────────────────────────

vpcs = {
  fiware-vpc = {
    name                 = "fiware-vpc"
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags                 = { Environment = "dev" }
  }
}

subnets = {
  # Tier público — ALB, NAT EIPs
  subnet-public-1a = {
    name              = "subnet-public-1a"
    cidr_block        = "10.0.101.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    ip_public_auto    = true
    network_acl_name  = "fiware-nacl"
  }
  subnet-public-1b = {
    name              = "subnet-public-1b"
    cidr_block        = "10.0.102.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    ip_public_auto    = true
    network_acl_name  = "fiware-nacl"
  }
  subnet-public-1c = {
    name              = "subnet-public-1c"
    cidr_block        = "10.0.103.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    ip_public_auto    = true
    network_acl_name  = "fiware-nacl"
  }
  # Tier app — nodos EKS
  subnet-app-1a = {
    name              = "subnet-app-1a"
    cidr_block        = "10.0.1.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
  }
  subnet-app-1b = {
    name              = "subnet-app-1b"
    cidr_block        = "10.0.2.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
  }
  subnet-app-1c = {
    name              = "subnet-app-1c"
    cidr_block        = "10.0.3.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
  }
  # Tier data — RDS, MongoDB, ElastiCache
  subnet-data-1a = {
    name              = "subnet-data-1a"
    cidr_block        = "10.0.11.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
  }
  subnet-data-1b = {
    name              = "subnet-data-1b"
    cidr_block        = "10.0.12.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
  }
  subnet-data-1c = {
    name              = "subnet-data-1c"
    cidr_block        = "10.0.13.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
  }
}

network_acls = {
  fiware-nacl = {
    name     = "fiware-nacl"
    vpc_name = "fiware-vpc"
    rules = {
      inbound_all = {
        rule_number = 100
        type        = "inbound"
        protocol    = "tcp"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 65535
      }
      outbound_all = {
        rule_number = 100
        type        = "outbound"
        protocol    = "tcp"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 65535
      }
    }
  }
}

internet_gateways = {
  fiware-igw = {
    name     = "fiware-igw"
    vpc_name = "fiware-vpc"
  }
}

nat_gateways = {
  nat-gw-1a = {
    name              = "nat-gw-1a"
    subnet_name       = "subnet-public-1a"
    connectivity_type = "public"
  }
}

subnet_route_tables = {
  rt-public = {
    name          = "rt-public"
    vpc_name      = "fiware-vpc"
    subnets_names = ["subnet-public-1a", "subnet-public-1b", "subnet-public-1c"]
    routes = {
      igw = { destiny = "0.0.0.0/0", target = "fiware-igw" }
    }
  }
  rt-app = {
    name          = "rt-app"
    vpc_name      = "fiware-vpc"
    subnets_names = ["subnet-app-1a", "subnet-app-1b", "subnet-app-1c"]
    routes = {
      nat = { destiny = "0.0.0.0/0", target = "nat-gw-1a" }
    }
  }
  rt-data = {
    name          = "rt-data"
    vpc_name      = "fiware-vpc"
    subnets_names = ["subnet-data-1a", "subnet-data-1b", "subnet-data-1c"]
    routes = {
      nat = { destiny = "0.0.0.0/0", target = "nat-gw-1a" }
    }
  }
}

# ─── Security Groups ──────────────────────────────────────────────────────────

security_groups = {
  eks-cluster-sg = {
    name        = "eks-cluster-sg"
    vpc_name    = "fiware-vpc"
    description = "EKS cluster control plane"
    ingress     = {}
    egress = {
      all = { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
    }
  }
  eks-node-sg = {
    name        = "eks-node-sg"
    vpc_name    = "fiware-vpc"
    description = "EKS worker nodes"
    ingress = {
      vpc_internal = {
        from_port   = 1025
        to_port     = 65535
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
        description = "Trafico interno VPC"
      }
    }
    egress = {
      all = { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
    }
  }
  alb-fiware-sg = {
    name        = "alb-fiware-sg"
    vpc_name    = "fiware-vpc"
    description = "ALB FIWARE publica"
    ingress = {
      http  = { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
      https = { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
    }
    egress = {
      all = { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
    }
  }
  data-sg = {
    name        = "data-sg"
    vpc_name    = "fiware-vpc"
    description = "Bases de datos — acceso solo desde nodos EKS"
    ingress = {
      mongodb = { from_port = 27017, to_port = 27017, protocol = "tcp", cidr_blocks = ["10.0.0.0/16"] }
      mysql   = { from_port = 3306, to_port = 3306, protocol = "tcp", cidr_blocks = ["10.0.0.0/16"] }
      pg      = { from_port = 5432, to_port = 5432, protocol = "tcp", cidr_blocks = ["10.0.0.0/16"] }
      redis   = { from_port = 6379, to_port = 6379, protocol = "tcp", cidr_blocks = ["10.0.0.0/16"] }
    }
    egress = {
      all = { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
    }
  }
}

# ─── S3 ───────────────────────────────────────────────────────────────────────

s3_buckets = {
  fiware-velero-backups = {
    name          = "fiware-velero-backups-101490102336"
    force_destroy = true
    versioning    = true
    tags          = { Purpose = "velero-backups" }
  }
  fiware-loki-logs = {
    name          = "fiware-loki-logs-101490102336"
    force_destroy = true
    versioning    = false
    tags          = { Purpose = "loki-logs" }
  }
}

# ─── DNS + TLS ────────────────────────────────────────────────────────────────

route53_zones = {
  lab = {
    name    = "lab-jdmonsalvel.com"
    comment = "Zona TFM lab"
    tags    = { Environment = "dev" }
  }
}

acm_certificates = {
  wildcard-lab = {
    domain_name               = "*.lab-jdmonsalvel.com"
    subject_alternative_names = ["lab-jdmonsalvel.com"]
    validation_method         = "DNS"
    zone_name                 = "lab-jdmonsalvel.com"
    tags                      = { Environment = "dev" }
  }
}

# ─── Secrets Manager ─────────────────────────────────────────────────────────

secrets_manager_secrets = {
  keyrock-admin = {
    name        = "/fiware/keyrock/admin-password"
    description = "Keyrock admin password"
    tags        = { Component = "keyrock" }
  }
  keyrock-db = {
    name        = "/fiware/keyrock/db-password"
    description = "Keyrock MySQL password"
    tags        = { Component = "keyrock" }
  }
  mysql-root = {
    name        = "/fiware/mysql/root-password"
    description = "MySQL root password"
    tags        = { Component = "mysql" }
  }
  mongodb-root = {
    name        = "/fiware/mongodb/root-password"
    description = "MongoDB root password"
    tags        = { Component = "mongodb" }
  }
}

# ─── IAM — OIDC GitHub Actions ───────────────────────────────────────────────

iam_oidc_providers = {
  github-actions = {
    url             = "https://token.actions.githubusercontent.com"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}

iam_roles = {
  github-actions-terraform = {
    name        = "github-actions-terraform-role"
    description = "Asumido por GitHub Actions via OIDC y por jdmonsalvel desde terminal"
    trust_statements = [
      {
        effect               = "Allow"
        actions              = ["sts:AssumeRoleWithWebIdentity"]
        federated_principals = ["arn:aws:iam::101490102336:oidc-provider/token.actions.githubusercontent.com"]
        conditions = {
          "StringLike"   = { "token.actions.githubusercontent.com:sub" = ["repo:jdmonsalvel/tfm-fiware-gitops:*"] }
          "StringEquals" = { "token.actions.githubusercontent.com:aud" = ["sts.amazonaws.com"] }
        }
      },
      {
        effect         = "Allow"
        actions        = ["sts:AssumeRole"]
        aws_principals = ["arn:aws:iam::101490102336:user/jdmonsalvel"]
        conditions     = {}
      }
    ]
    managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

eks_backend_bucket = "devops-101490102336-terraform-state-bucket"
eks_backend_region = "eu-west-1"

eks = {
  fiware-gitops = {
    network = {
      vpc_name             = "fiware-vpc"
      subnet_names         = ["subnet-app-1a", "subnet-app-1b", "subnet-app-1c"]
      endpoint_public_access  = false
      endpoint_private_access = true
    }

    cluster = {
      kubernetes_version = "1.29"
      deletion_protection = false
    }

    auth = {
      admins = {
        principal_arns = ["arn:aws:iam::101490102336:user/jdmonsalvel"]
      }
    }

    node_groups = {
      workload_node_groups = {
        fiware = {
          instance_types = ["t3.xlarge"]
          capacity_type  = "SPOT"
          min_size       = 2
          max_size       = 4
          desired_size   = 3
          disk_size      = 50
          labels         = { workload = "fiware" }
        }
      }
    }

    tags = { Component = "eks" }
  }
}
