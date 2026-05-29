module "eks" {
  source = "../../"

  backend_bucket = "my-terraform-state-bucket"
  backend_region = "eu-west-1"

  eks = {
    prod-cluster = {
      account = {
        region          = "eu-west-1"
        assume_role_arn = "arn:aws:iam::123456789012:role/automate-cicd-role"
      }

      network = {
        vpc_id                   = "vpc-0abc123def456789"
        subnet_ids               = ["subnet-0aaa111", "subnet-0bbb222", "subnet-0ccc333"]
        control_plane_subnet_ids = ["subnet-0ddd444", "subnet-0eee555", "subnet-0fff666"]
        endpoint_public_access   = false
        endpoint_private_access  = true
      }

      cluster = {
        kubernetes_version  = "1.33"
        authentication_mode = "API"
        enabled_log_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
        kms_create_key      = true
        deletion_protection = true
        upgrade_policy      = "STANDARD"
      }

      auth = {
        mode = "access_entries"
        admins = {
          principal_arns    = ["arn:aws:iam::123456789012:role/platform-admin"]
          kubernetes_groups = ["platform-admins"]
        }
        developers = {
          principal_arns    = ["arn:aws:iam::123456789012:role/developers"]
          kubernetes_groups = ["platform-developers"]
        }
        additional_access_entries = {
          ci-runner = {
            principal_arn       = "arn:aws:iam::123456789012:role/gitlab-runner"
            type                = "STANDARD"
            policy_associations = ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"]
          }
        }
      }

      addons = {
        cert_manager                 = true
        aws_load_balancer_controller = true
        external_secrets             = true
        external_dns                 = true
        metrics_server               = true
        velero                       = true
        reloader                     = true
        karpenter                    = false
        cluster_autoscaler           = true

        helm_chart_versions = {
          cert_manager = "v1.17.2"
        }
      }

      monitoring = {
        mode = "standard"
        storage = {
          s3_bucket_name = "my-monitoring-bucket-prod"
          retention_days = 30
          create_bucket  = true
        }
      }

      compute = {
        cluster_tools_node_group = {
          capacity_type  = "ON_DEMAND"
          instance_types = ["m7i.large"]
          min_size       = 2
          max_size       = 4
          desired_size   = 2
          disk_size      = 50
          labels         = { workload = "cluster-tools" }
          taints = [{
            key    = "CriticalAddonsOnly"
            value  = "true"
            effect = "NO_SCHEDULE"
          }]
        }
        workload_node_groups = {
          general = {
            capacity_type  = "ON_DEMAND"
            instance_types = ["m7i.xlarge", "m7i.2xlarge"]
            min_size       = 2
            max_size       = 20
            desired_size   = 3
            disk_size      = 100
            labels         = { workload = "general" }
          }
          spot = {
            capacity_type  = "SPOT"
            instance_types = ["m7i.xlarge", "m6i.xlarge", "m5.xlarge"]
            min_size       = 0
            max_size       = 10
            desired_size   = 0
            labels         = { workload = "batch", "eks.amazonaws.com/capacityType" = "SPOT" }
          }
        }
      }

      tags = {
        Environment = "production"
        CostCenter  = "platform"
      }
    }
  }

  tags = {
    Project   = "tfm-fiware-gitops"
    ManagedBy = "terraform"
  }
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoints["prod-cluster"]
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arns["prod-cluster"]
}
