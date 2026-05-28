module "vpc" {
  source = "./modules/aws/vpc"
  tags   = local.tags
  vpcs   = var.vpcs
  region = var.region
}
module "subnet" {
  source          = "./modules/aws/subnet"
  tags            = local.tags
  subnets         = var.subnets
  region          = var.region
  vpc_ids         = local.vpc_ids
  network_acl_ids = module.network_acl.network_acl_ids
}
module "network_acl" {
  source       = "./modules/aws/network-acl"
  tags         = local.tags
  network_acls = var.network_acls
  vpc_ids      = local.vpc_ids
}
module "dhcp_option_set" {
  source = "./modules/aws/dhcp"

  tags             = local.tags
  dhcp_option_sets = var.dhcp_option_sets
  vpc_ids          = local.vpc_ids
  region           = var.region
}
module "internet_gateways" {
  source            = "./modules/aws/intenet-gw"
  tags              = local.tags
  internet_gateways = var.internet_gateways
  vpc_ids           = local.vpc_ids
}
module "nat_gw" {
  source       = "./modules/aws/nat-gw"
  region       = var.region
  tags         = local.tags
  nat_gateways = var.nat_gateways
  subnet_ids   = local.subnet_ids
  depends_on   = [local.subnet_ids]
}
module "security_group" {
  source          = "./modules/aws/security-group"
  tags            = local.tags
  vpc_ids         = local.vpc_ids
  security_groups = var.security_groups
  depends_on      = [local.vpc_ids]
}
module "transit_gateway_attachment" {
  source                      = "./modules/aws/transit-gw-attach"
  region                      = var.region
  tags                        = local.tags
  vpc_ids                     = local.vpc_ids
  subnet_ids                  = local.subnet_ids
  transit_gateway_ids         = module.transit_gateway.transit_gateway_ids
  transit_gateway_attachments = var.transit_gateway_attachments
}
module "subnet_route_table" {
  source                         = "./modules/aws/subnet-route-table"
  subnet_route_tables            = var.subnet_route_tables
  vpc_ids                        = local.vpc_ids
  subnet_ids                     = local.subnet_ids
  transit_gateway_ids            = module.transit_gateway.transit_gateway_ids
  tags                           = local.tags
  transit_gateway_attachment_ids = module.transit_gateway_attachment.transit_gateway_attachment_ids
  internet_gateway_ids           = module.internet_gateways.internet_gateway_ids
  nat_gateway_ids                = module.nat_gw.nat_gateway_ids
  regional_nat_gateway_ids       = length(module.regional_nat_gw) > 0 ? module.regional_nat_gw[0].regional_nat_gateway_ids : {}
}

module "transit_gateway" {
  source           = "./modules/aws/transit-gw"
  tags             = local.tags
  transit_gateways = var.transit_gateways
}

module "transit_gateway_route_table" {
  source                         = "./modules/aws/transit-gw-route-table"
  count                          = length(var.transit_gateway_route_tables) > 0 ? 1 : 0
  tags                           = local.tags
  transit_gateway_route_tables   = var.transit_gateway_route_tables
  transit_gateway_ids            = module.transit_gateway.transit_gateway_ids
  transit_gateway_attachment_ids = module.transit_gateway_attachment.transit_gateway_attachment_ids
  depends_on                     = [module.transit_gateway]
}

module "db_subnet_group" {
  count         = length(module.subnet.db_subnet_ids) > 0 ? 1 : 0
  source        = "./modules/aws/db-subnet-group"
  db_subnet_ids = module.subnet.db_subnet_ids
  name          = "${var.project}-${var.environment}-db-subnet-group"
  tags          = local.tags
}

module "rds" {
  count                = length(var.rds_instances) > 0 ? 1 : 0
  source               = "./modules/aws/rds"
  rds_instances        = var.rds_instances
  db_subnet_group_name = module.db_subnet_group[0].db_subnet_group_name
  security_group_ids   = module.security_group.security_group_ids
  tags                 = local.tags
  depends_on           = [module.db_subnet_group]
}

module "kms" {
  count    = length(var.kms_keys) > 0 ? 1 : 0
  source   = "./modules/aws/kms"
  tags     = local.tags
  kms_keys = var.kms_keys
}

module "iam" {
  count               = (length(var.iam_roles) + length(var.iam_policies) + length(var.iam_users) + length(var.iam_groups) + length(var.iam_oidc_providers)) > 0 ? 1 : 0
  source              = "./modules/aws/iam"
  tags                = local.tags
  iam_roles           = var.iam_roles
  iam_policies        = var.iam_policies
  iam_users           = var.iam_users
  iam_groups          = var.iam_groups
  iam_oidc_providers  = var.iam_oidc_providers
}

module "regional_nat_gw" {
  count                 = length(var.regional_nat_gateways) > 0 ? 1 : 0
  source                = "./modules/aws/regional-nat-gw"
  tags                  = local.tags
  regional_nat_gateways = var.regional_nat_gateways
}

module "eks" {
  count          = length(var.eks) > 0 ? 1 : 0
  source         = "./modules/aws/eks"
  tags           = local.tags
  backend_bucket = var.eks_backend_bucket
  backend_region = var.eks_backend_region

  # Resuelve nombres de VPC/subnet a IDs usando los outputs de los módulos de red.
  # En el tfvars se usan claves (vpc_name, subnet_names) en lugar de IDs hardcodeados.
  eks = {
    for k, v in var.eks : k => merge(v, {
      network = {
        vpc_id                                  = local.vpc_ids[v.network.vpc_name]
        subnet_ids                              = [for s in v.network.subnet_names : local.subnet_ids[s]]
        control_plane_subnet_ids                = try(v.network.control_plane_subnet_names, null) != null ? [for s in v.network.control_plane_subnet_names : local.subnet_ids[s]] : null
        endpoint_public_access                  = try(v.network.endpoint_public_access, false)
        endpoint_private_access                 = try(v.network.endpoint_private_access, true)
        public_access_cidrs                     = try(v.network.public_access_cidrs, ["0.0.0.0/0"])
        cluster_security_group_additional_rules = try(v.network.cluster_security_group_additional_rules, {})
      }
    })
  }
}

module "s3" {
  count      = length(var.s3_buckets) > 0 ? 1 : 0
  source     = "./modules/aws/s3"
  tags       = local.tags
  s3_buckets = var.s3_buckets
}

module "ecr" {
  count                = length(var.ecr_repositories) > 0 ? 1 : 0
  source               = "./modules/aws/ecr"
  tags                 = local.tags
  ecr_repositories     = var.ecr_repositories
  registry_scanning    = var.registry_scanning
  registry_replication = var.registry_replication
}

module "ec2" {
  source          = "./modules/aws/ec2"
  count           = length(var.ec2_instances) > 0 ? 1 : 0
  environment     = var.environment
  tags            = local.tags
  security_groups = module.security_group.security_group_ids
  subnets         = module.subnet.subnet_ids
  instances       = var.ec2_instances
  project         = var.project
  depends_on      = [var.security_groups]
  keypairs        = module.keypairs.key_pair_names
}

module "keypairs" {
  source      = "./modules/aws/keypair"
  region      = var.region
  keypairs    = var.keypairs
  tags        = local.tags
  environment = var.environment
}

module "route53" {
  count           = (length(var.route53_zones) + length(var.route53_records)) > 0 ? 1 : 0
  source          = "./modules/aws/route53"
  tags            = local.tags
  route53_zones   = var.route53_zones
  route53_records = var.route53_records
}

module "acm" {
  count            = length(var.acm_certificates) > 0 ? 1 : 0
  source           = "./modules/aws/acm"
  tags             = local.tags
  acm_certificates = var.acm_certificates
  zone_ids         = length(module.route53) > 0 ? module.route53[0].zone_ids : {}
}

module "instance_scheduler" {
  count               = length(var.instance_schedulers) > 0 ? 1 : 0
  source              = "./modules/aws/instance-scheduler"
  tags                = local.tags
  instance_schedulers = var.instance_schedulers
}

module "autoscaling_group" {
  source             = "./modules/aws/auto-scaling-group"
  count              = length(var.autoscaling_groups) > 0 ? 1 : 0
  autoscaling_groups = var.autoscaling_groups
  region             = var.region
  tags               = local.tags
  project            = var.project
  environment        = var.environment
  security_groups    = module.security_group.security_group_ids
  subnets            = module.subnet.subnet_ids
  keypairs           = module.keypairs.key_pair_names
  vpc_ids            = local.vpc_ids
}

module "secrets_manager" {
  count                   = length(var.secrets_manager_secrets) > 0 ? 1 : 0
  source                  = "./modules/aws/secrets-manager"
  tags                    = local.tags
  secrets_manager_secrets = var.secrets_manager_secrets
}

# ──────────────────────────────────────────────────────────────────────────────
# REGLAS CROSS-SG — ingress entre security groups del mismo mapa
# Se crean tras el módulo security_group para evitar dependencia circular.
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_vpc_security_group_ingress_rule" "cross_sg" {
  for_each = var.security_group_rules

  security_group_id            = module.security_group.security_group_ids[each.value.sg_name]
  referenced_security_group_id = each.value.source_sg_name != null ? module.security_group.security_group_ids[each.value.source_sg_name] : null
  cidr_ipv4                    = each.value.cidr_ipv4

  from_port   = each.value.from_port >= 0 ? each.value.from_port : null
  to_port     = each.value.to_port >= 0 ? each.value.to_port : null
  ip_protocol = each.value.ip_protocol

  description = each.value.description

  tags = merge(local.tags, { Name = each.key })
}
