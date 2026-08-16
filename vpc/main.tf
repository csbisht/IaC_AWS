module "vpc" {
  source = "./modules/vpc"

  # Naming
  aws_region  = var.aws_region
  name_prefix = var.name_prefix

  # VPC
  vpc_cidr             = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  # Subnets
  subnet_groups = var.subnet_groups

  # Internet access
  create_internet_gateway = var.create_internet_gateway
  nat_gateway_mode        = var.nat_gateway_mode

  # VPC endpoints
  gateway_endpoints               = var.gateway_endpoints
  interface_endpoints             = var.interface_endpoints
  interface_endpoint_subnet_group = var.interface_endpoint_subnet_group
  interface_endpoint_private_dns  = var.interface_endpoint_private_dns
  vpc_endpoint_ingress_cidrs      = var.vpc_endpoint_ingress_cidrs
}
