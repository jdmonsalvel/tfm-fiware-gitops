account_id  = ""
region      = "eu-central-1"
project     = "platform-engineering"
environment = "dev"
accountable = "jdmonsalvel"

vpcs = {
  example-vpc = {
    name                 = "example-vpc"
    cidr_block           = "172.16.0.0/16"
    instance_tenancy     = "default"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
      test = "test"
    }
  }
}
# dhcp_option_sets = {
#   dhcp-option-set-example = {
#     name        = "dhcp-option-set-example"
#     domain_name = "example.local"
#     vpc_name    = "example-vpc"
#     tags = {
#       test = "test"
#     }
#   }
# }
subnets = {
  subnet-frontend-a = {
    name              = "subnet-frontend-a"
    cidr_block        = "172.16.1.0/24"
    availability_zone = "a"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
  subnet-frontend-b = {
    name              = "subnet-frontend-b"
    cidr_block        = "172.16.2.0/24"
    availability_zone = "b"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
  subnet-backend-a = {
    name              = "subnet-backend-a"
    cidr_block        = "172.16.3.0/24"
    availability_zone = "a"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
  subnet-backend-b = {
    name              = "subnet-backend-b"
    cidr_block        = "172.16.4.0/24"
    availability_zone = "b"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
  subnet-public-a = {
    name              = "subnet-public-a"
    cidr_block        = "172.16.5.0/24"
    availability_zone = "a"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    ip_public_auto    = true
    tags = {
      test = "test"
    }
  }
  subnet-public-b = {
    name              = "subnet-public-b"
    cidr_block        = "172.16.6.0/24"
    availability_zone = "b"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    ip_public_auto    = true
    tags = {
      test = "test"
    }
  }
  subnet-transit-a = {
    name              = "subnet-transit-a"
    cidr_block        = "172.16.7.0/24"
    availability_zone = "a"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
  subnet-transit-b = {
    name              = "subnet-transit-b"
    cidr_block        = "172.16.8.0/24"
    availability_zone = "b"
    vpc_name          = "example-vpc"
    network_acl_name  = "network-acl-example"
    tags = {
      test = "test"
    }
  }
}
subnet_route_tables = {
  subnet-route-table-example-az-a = {
    name          = "subnet-route-table-example-az-a"
    vpc_name      = "example-vpc"
    subnets_names = ["subnet-frontend-a", "subnet-backend-a"]
    routes = {
      route-nat-gw = {
        destiny = "0.0.0.0/0"
        target  = "nat-gateway-example-az-a"
      }
    }
  }
  subnet-route-table-example-az-b = {
    name          = "subnet-route-table-example-az-b"
    vpc_name      = "example-vpc"
    subnets_names = ["subnet-frontend-b", "subnet-backend-b"]
    routes = {
      route-nat-gw = {
        destiny = "0.0.0.0/0"
        target  = "nat-gateway-example-az-a"
      }
    }
  }
  subnet-route-table-example-public = {
    name          = "subnet-route-table-example-public"
    vpc_name      = "example-vpc"
    subnets_names = ["subnet-public-a", "subnet-public-b", ]
    routes = {
      route-internet-gw = {
        destiny = "0.0.0.0/0"
        target  = "example-igw"
      }
    }
    route-SharedResources = {
      destiny = "10.255.176.0/21"
      target  = "transit-gw-attach-example"
    }
  }
}
network_acls = {
  network-acl-example = {
    name     = "network-acl-example"
    vpc_name = "example-vpc"
    rules = {
      rule_all_inbound = {
        rule_number = 100
        type        = "inbound"
        protocol    = "tcp"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 65535
      }
      rule_all_outbound = {
        rule_number = 100
        type        = "outbound"
        protocol    = "tcp"
        rule_action = "allow"
        cidr_block  = "0.0.0.0/0"
        from_port   = 0
        to_port     = 65535
      }
    }
    tags = {
      test = "test"
    }
  }
}
internet_gateways = {
  example-igw = {
    name     = "example-igw"
    vpc_name = "example-vpc"
    tags = {
      test = "test"
    }
  }
}
nat_gateways = {
  nat-gateway-example-az-a = {
    name              = "nat-gateway-example-az-a"
    subnet_name       = "subnet-public-a"
    connectivity_type = "public"
    tags = {
      test = "test"
    }
  }
  nat-gateway-example-az-b = {
    name              = "nat-gateway-example-az-b"
    subnet_name       = "subnet-public-b"
    connectivity_type = "public"
    tags = {
      test = "test"
    }
  }
}
transit_gateways = {
  example-tgw = {
    name            = "example-tgw"
    description     = "Primary Transit Gateway"
    amazon_side_asn = 64512
    tags = {
      test = "test"
    }
  }
}
transit_gateway_attachments = {
  example-tgw-attach = {
    name                 = "example-tgw-attach"
    vpc_name             = "example-vpc"
    transit_gateway_name = "example-tgw"
    subnet_names         = ["subnet-transit-a", "subnet-transit-b"]
  }
}
transit_gateway_route_tables = {
  example-tgw-rt = {
    name                 = "example-tgw-rt"
    transit_gateway_name = "example-tgw"
    routes = {
      route-example-tgw-attach = {
        destiny = "0.0.0.0/0"
        target  = "example-tgw-attach"
      }
      route-example-test-tgw-attach = {
        destiny = "10.0.0.0/8"
        target  = "example-tgw-attach"
      }
    }
    tags = {
      test = "test"
    }
  }
}
security_groups = {
  web-server-asg-sg = {
    vpc_name    = "example-vpc"
    name        = "web-server-asg-sg"
    description = "Security group for web servers"
    ingress = {
      http = {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP access"
      }
      https = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS access"
      }
      ssh = {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "SSH from VPC"
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
    tags = {
      Environment = "dev"
    }
  }

  db-server-sg = {
    vpc_name = "example-vpc"
    name     = "db-server-sg"
    ingress = {
      mongodb = {
        from_port   = 27017
        to_port     = 27017
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
      ssh = {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "SSH from VPC"
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
  }

  alb-asg-sg = {
    vpc_name    = "example-vpc"
    name        = "alb-asg-sg"
    description = "Security group for web servers"
    ingress = {
      http = {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP access"
      }
      https = {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS access"
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
    tags = {
      Environment = "dev"
    }
  }
}
ec2_instances = {
  mogodb-server = {
    name            = "mogodb-server"
    ami             = "ami-0e8a986076c1bad5a"
    instance_type   = "t3a.medium"
    subnet_name     = "subnet-public-a"
    security_groups = ["db-server-sg"]
    key_pair        = "key-test"
    public          = true
  }
}

keypairs = {
  key-test = {
    name = "key-test"
  }
}

autoscaling_groups = {
  web-server = {
    name                      = "web-server"
    vpc_name                  = "example-vpc"
    instance_subnets          = ["subnet-frontend-a", "subnet-frontend-b"]
    alb_subnets               = ["subnet-public-a", "subnet-public-b"]
    alb_internal              = false
    alb_security_groups       = ["alb-asg-sg"]
    instances_security_groups = ["web-server-asg-sg"]
    instance_type             = "t3a.micro"
    ami_id                    = "ami-0e6d77d186661ab39"
    min_size                  = 2
    max_size                  = 5
    desired_capacity          = 2
    key_pair                  = "key-test"
    certificate_arn           = null
    policy_enabled            = false
    health_check_path         = "/"
    listener_port_http        = 80
    tags = {
      Environment = "dev"
      Project     = "platform-engineering"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# IAM — OIDC provider + rol GitHub Actions
# Reemplaza credenciales estáticas: ninguna credencial queda en el repo ni en
# GitHub Secrets. El token JWT de GitHub Actions es verificado directamente por
# AWS IAM en cada ejecución del pipeline.
# ──────────────────────────────────────────────────────────────────────────────

# Paso 1: registrar GitHub Actions como OIDC provider en la cuenta AWS
iam_oidc_providers = {
  github-actions = {
    url             = "https://token.actions.githubusercontent.com"
    client_id_list  = ["sts.amazonaws.com"]
    # Thumbprint del certificado raíz de GitHub OIDC (válido hasta 2035)
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}

# Paso 2: rol que GitHub Actions asumirá vía OIDC
# El ARN del provider es determinista: arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
iam_roles = {
  github-actions-terraform = {
    name        = "github-actions-terraform-role"
    description = "Asumido por GitHub Actions via OIDC — sin credenciales estaticas"

    trust_statements = [
      {
        effect  = "Allow"
        actions = ["sts:AssumeRoleWithWebIdentity"]

        # Reemplazar <ACCOUNT_ID> con el ID de la cuenta AWS
        federated_principals = ["arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"]

        conditions = {
          # Solo el repo del TFM puede asumir este rol
          "StringLike" = {
            "token.actions.githubusercontent.com:sub" = ["repo:<GITHUB_ORG>/<GITHUB_REPO>:*"]
          }
          # Audience requerido por AWS
          "StringEquals" = {
            "token.actions.githubusercontent.com:aud" = ["sts.amazonaws.com"]
          }
        }
      }
    ]

    # En entorno de laboratorio se usa AdministratorAccess.
    # En producción: sustituir por política con solo los permisos necesarios para Terraform.
    managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }
}
