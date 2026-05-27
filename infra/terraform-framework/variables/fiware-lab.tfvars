# ============================================================
#  TFM — FIWARE GitOps Lab (Floci / LocalStack)
#  Región: eu-west-1  |  Account: 000000000000 (emulada)
#
#  Secuencia de apply:
#    Fase 1 (este archivo): VPC, subnets, red, S3
#    Fase 2: añadir bloque "eks" con los IDs que devuelva
#            `terraform output -json` tras la fase 1
# ============================================================

use_floci   = true
account_id  = "000000000000"
region      = "eu-west-1"
project     = "tfm-fiware-gitops"
environment = "lab"
accountable = "jdmonsalvel"

# ── Backends EKS (S3 para state del addon-bootstrap) ─────────
eks_backend_bucket = "tfm-fiware-terraform-state"
eks_backend_region = "eu-west-1"

# ────────────────────────────────────────────────────────────
# VPC
# ────────────────────────────────────────────────────────────
vpcs = {
  fiware-vpc = {
    name                 = "tfm-fiware-vpc"
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
      Tier = "network"
    }
  }
}

# ────────────────────────────────────────────────────────────
# Subnets
# 3 AZs: eu-west-1a / eu-west-1b / eu-west-1c
#   Public  (ALB + NAT GW):   10.0.101-103.0/24
#   Private app (EKS nodes):  10.0.1-3.0/24
#   Private data (RDS/DocDB): 10.0.201-203.0/24
# ────────────────────────────────────────────────────────────
subnets = {

  # ── Públicas ─────────────────────────────────────────────
  pub-a = {
    name              = "tfm-fiware-pub-a"
    cidr_block        = "10.0.101.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    ip_public_auto    = true
    tags = { Tier = "public", "kubernetes.io/role/elb" = "1" }
  }
  pub-b = {
    name              = "tfm-fiware-pub-b"
    cidr_block        = "10.0.102.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    ip_public_auto    = true
    tags = { Tier = "public", "kubernetes.io/role/elb" = "1" }
  }
  pub-c = {
    name              = "tfm-fiware-pub-c"
    cidr_block        = "10.0.103.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    ip_public_auto    = true
    tags = { Tier = "public", "kubernetes.io/role/elb" = "1" }
  }

  # ── Privadas app (EKS) ───────────────────────────────────
  priv-app-a = {
    name              = "tfm-fiware-priv-app-a"
    cidr_block        = "10.0.1.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    tags = { Tier = "private-app", "kubernetes.io/role/internal-elb" = "1" }
  }
  priv-app-b = {
    name              = "tfm-fiware-priv-app-b"
    cidr_block        = "10.0.2.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    tags = { Tier = "private-app", "kubernetes.io/role/internal-elb" = "1" }
  }
  priv-app-c = {
    name              = "tfm-fiware-priv-app-c"
    cidr_block        = "10.0.3.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    tags = { Tier = "private-app", "kubernetes.io/role/internal-elb" = "1" }
  }

  # ── Privadas data ────────────────────────────────────────
  priv-data-a = {
    name              = "tfm-fiware-priv-data-a"
    cidr_block        = "10.0.201.0/24"
    availability_zone = "a"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
    tags = { Tier = "private-data" }
  }
  priv-data-b = {
    name              = "tfm-fiware-priv-data-b"
    cidr_block        = "10.0.202.0/24"
    availability_zone = "b"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
    tags = { Tier = "private-data" }
  }
  priv-data-c = {
    name              = "tfm-fiware-priv-data-c"
    cidr_block        = "10.0.203.0/24"
    availability_zone = "c"
    vpc_name          = "fiware-vpc"
    network_acl_name  = "fiware-nacl"
    db_subnet         = true
    tags = { Tier = "private-data" }
  }
}

# ────────────────────────────────────────────────────────────
# Network ACL
# ────────────────────────────────────────────────────────────
network_acls = {
  fiware-nacl = {
    name     = "tfm-fiware-nacl"
    vpc_name = "fiware-vpc"
    rules = {
      inbound-all = {
        rule_number = 100
        type        = "inbound"
        protocol    = "-1"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 0
      }
      outbound-all = {
        rule_number = 100
        type        = "outbound"
        protocol    = "-1"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 0
      }
    }
  }
}

# ────────────────────────────────────────────────────────────
# Internet Gateway
# ────────────────────────────────────────────────────────────
internet_gateways = {
  fiware-igw = {
    name     = "tfm-fiware-igw"
    vpc_name = "fiware-vpc"
  }
}

# ────────────────────────────────────────────────────────────
# NAT Gateways (uno por AZ para HA)
# ────────────────────────────────────────────────────────────
nat_gateways = {
  nat-a = {
    name              = "tfm-fiware-nat-a"
    subnet_name       = "pub-a"
    connectivity_type = "public"
  }
  nat-b = {
    name              = "tfm-fiware-nat-b"
    subnet_name       = "pub-b"
    connectivity_type = "public"
  }
  nat-c = {
    name              = "tfm-fiware-nat-c"
    subnet_name       = "pub-c"
    connectivity_type = "public"
  }
}

# ────────────────────────────────────────────────────────────
# Route Tables
# ────────────────────────────────────────────────────────────
subnet_route_tables = {

  # Públicas → IGW
  rt-public = {
    name          = "tfm-fiware-rt-public"
    vpc_name      = "fiware-vpc"
    subnets_names = ["pub-a", "pub-b", "pub-c"]
    routes = {
      default = {
        destiny = "0.0.0.0/0"
        target  = "fiware-igw"
      }
    }
  }

  # Privadas AZ-a → NAT-a
  rt-priv-a = {
    name          = "tfm-fiware-rt-priv-a"
    vpc_name      = "fiware-vpc"
    subnets_names = ["priv-app-a", "priv-data-a"]
    routes = {
      default = {
        destiny = "0.0.0.0/0"
        target  = "nat-a"
      }
    }
  }

  # Privadas AZ-b → NAT-b
  rt-priv-b = {
    name          = "tfm-fiware-rt-priv-b"
    vpc_name      = "fiware-vpc"
    subnets_names = ["priv-app-b", "priv-data-b"]
    routes = {
      default = {
        destiny = "0.0.0.0/0"
        target  = "nat-b"
      }
    }
  }

  # Privadas AZ-c → NAT-c
  rt-priv-c = {
    name          = "tfm-fiware-rt-priv-c"
    vpc_name      = "fiware-vpc"
    subnets_names = ["priv-app-c", "priv-data-c"]
    routes = {
      default = {
        destiny = "0.0.0.0/0"
        target  = "nat-c"
      }
    }
  }
}

# ────────────────────────────────────────────────────────────
# Security Groups
# ────────────────────────────────────────────────────────────
security_groups = {

  # Control plane EKS — acceso desde nodos y kubectl
  eks-cluster-sg = {
    vpc_name    = "fiware-vpc"
    name        = "tfm-fiware-eks-cluster"
    description = "EKS control plane — acceso desde nodos y administradores"
    ingress = {
      kubectl = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "kubectl desde VPC"
      }
    }
    egress = {
      all = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
    tags = { Component = "eks" }
  }

  # Nodos EKS — comunicación entre pods y con ALB
  eks-node-sg = {
    vpc_name    = "fiware-vpc"
    name        = "tfm-fiware-eks-nodes"
    description = "Nodos EKS — inter-pod y ALB"
    ingress = {
      node-ports = {
        from_port   = 1025
        to_port     = 65535
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "Puertos de pods"
      }
      nodeport = {
        from_port   = 30000
        to_port     = 32767
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "NodePort"
      }
    }
    egress = {
      all = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
    tags = { Component = "eks" }
  }

  # ALB para FIWARE endpoints
  alb-fiware-sg = {
    vpc_name    = "fiware-vpc"
    name        = "tfm-fiware-alb"
    description = "ALB para FIWARE endpoints"
    ingress = {
      https = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS público"
      }
      http = {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP — redirect a HTTPS"
      }
    }
    egress = {
      all = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
    tags = { Component = "alb" }
  }
}

# ────────────────────────────────────────────────────────────
# S3 Buckets
# ────────────────────────────────────────────────────────────
s3_buckets = {

  # State de Terraform
  terraform-state = {
    name          = "tfm-fiware-terraform-state"
    force_destroy = true
    versioning    = true
    tags          = { Purpose = "terraform-backend" }
  }

  # Backups Velero
  velero-backups = {
    name          = "tfm-fiware-velero-backups"
    force_destroy = true
    versioning    = true
    tags          = { Purpose = "velero-dr" }
  }

  # Logs Loki
  loki-logs = {
    name          = "tfm-fiware-loki-logs"
    force_destroy = true
    versioning    = false
    tags          = { Purpose = "observability-logs" }
  }
}

# ────────────────────────────────────────────────────────────
# EKS — FASE 2
# Descomentar y completar los IDs tras ejecutar la fase 1:
#   terraform output -json | jq '{vpc_ids, subnet_ids}'
# ────────────────────────────────────────────────────────────
# eks = {
#   fiware-gitops = {
#     network = {
#       vpc_id                  = "<ID del output vpc_ids[\"fiware-vpc\"]>"
#       subnet_ids              = [
#         "<priv-app-a>", "<priv-app-b>", "<priv-app-c>",
#       ]
#       control_plane_subnet_ids = [
#         "<priv-app-a>", "<priv-app-b>", "<priv-app-c>",
#       ]
#       endpoint_public_access  = true    # lab: kubectl desde fuera de VPC
#       endpoint_private_access = true
#       public_access_cidrs     = ["0.0.0.0/0"]
#     }
#     cluster = {
#       kubernetes_version           = "1.29"
#       authentication_mode          = "API_AND_CONFIG_MAP"
#       enable_cluster_creator_admin = true
#       deletion_protection          = false   # lab: permite destroy
#       enabled_log_types            = ["api", "audit", "authenticator"]
#     }
#     compute = {
#       workload_node_groups = {
#         fiware = {
#           capacity_type  = "ON_DEMAND"
#           instance_types = ["t3.xlarge"]   # 4 vCPU / 16 GB — mínimo para FIWARE
#           min_size       = 2
#           max_size       = 4
#           desired_size   = 3
#           disk_size      = 100
#           labels         = { workload = "fiware" }
#         }
#       }
#     }
#     addons = {
#       coredns                      = true
#       kube_proxy                   = true
#       vpc_cni                      = true
#       ebs_csi                      = true
#       aws_load_balancer_controller = true
#       external_secrets             = true
#       metrics_server               = true
#       cert_manager                 = true
#     }
#     monitoring = {
#       mode = "standalone"
#       storage = {
#         s3_bucket_name = "tfm-fiware-loki-logs"
#         retention_days = 30
#         create_bucket  = false
#       }
#     }
#     tags = { Component = "eks" }
#   }
# }
