module "eks" {
  source = "../../"

  backend_bucket = "my-terraform-state-bucket"
  backend_region = "eu-west-1"

  eks = {
    dev-cluster = {
      network = {
        vpc_id     = "vpc-0abc123def456789"
        subnet_ids = ["subnet-0aaa111", "subnet-0bbb222", "subnet-0ccc333"]
      }

      cluster = {
        kubernetes_version  = "1.33"
        deletion_protection = false
      }

      addons = {
        cert_manager     = true
        external_secrets = true
        metrics_server   = true
      }

      compute = {
        cluster_tools_node_group = {
          instance_types = ["m7i.large"]
          min_size       = 1
          max_size       = 3
          desired_size   = 1
        }
        workload_node_groups = {
          general = {
            instance_types = ["m7i.xlarge"]
            min_size       = 1
            max_size       = 5
            desired_size   = 2
          }
        }
      }
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
