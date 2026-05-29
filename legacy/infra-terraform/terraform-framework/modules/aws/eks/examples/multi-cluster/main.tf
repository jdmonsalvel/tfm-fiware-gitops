module "eks" {
  source = "../../"

  backend_bucket = "my-terraform-state-bucket"
  backend_region = "eu-west-1"

  eks = {
    # Hub cluster — plataforma
    platform = {
      network = {
        vpc_id     = "vpc-0hub111"
        subnet_ids = ["subnet-hub-a", "subnet-hub-b", "subnet-hub-c"]
      }
      cluster = { kubernetes_version = "1.33" }
      addons  = { karpenter = true, cluster_autoscaler = false }
      compute = {
        cluster_tools_node_group = { instance_types = ["m7i.large"], min_size = 2, max_size = 4, desired_size = 2 }
        workload_node_groups = {
          karpenter-infra = { instance_types = ["m7i.xlarge"], min_size = 1, max_size = 3, desired_size = 1 }
        }
      }
      monitoring = { mode = "standard", storage = { s3_bucket_name = "monitoring-platform" } }
      tags       = { Role = "platform-hub" }
    }

    # Tenant cluster — aplicaciones negocio
    tenant-prod = {
      network = {
        vpc_id     = "vpc-0tenant111"
        subnet_ids = ["subnet-tenant-a", "subnet-tenant-b", "subnet-tenant-c"]
      }
      cluster = {
        kubernetes_version  = "1.33"
        authentication_mode = "API"
      }
      auth = {
        mode = "access_entries"
        admins = {
          principal_arns = ["arn:aws:iam::999888777666:role/platform-admin"]
        }
      }
      addons = {
        cluster_autoscaler = true
        external_dns       = true
        istio              = true
      }
      monitoring = {
        mode = "centralized"
        centralized_config = {
          metrics = {
            enabled          = true
            remote_write_url = "https://prometheus.platform.internal/api/v1/write"
          }
          logs = {
            enabled  = true
            endpoint = "https://loki.platform.internal/loki/api/v1/push"
          }
          traces = {
            enabled  = true
            endpoint = "otel-collector.platform.internal:4317"
          }
        }
      }
      compute = {
        workload_node_groups = {
          app = { instance_types = ["m7i.2xlarge"], min_size = 2, max_size = 15, desired_size = 3 }
        }
      }
      tags = { Role = "tenant-prod" }
    }
  }

  tags = {
    ManagedBy = "terraform"
  }
}

output "all_endpoints" {
  value = module.eks.cluster_endpoints
}
