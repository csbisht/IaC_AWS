########################################
# VPC
########################################

output "vpc_id" {
  description = "Id of the created VPC. This is the vpc_id the ec2 and eks-cluster configurations ask for."
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN of the created VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr" {
  description = "IPv4 CIDR of the created VPC."
  value       = module.vpc.vpc_cidr
}

output "vpc_name" {
  description = "Name tag of the created VPC."
  value       = module.vpc.vpc_name
}

output "default_security_group_id" {
  description = "The security group AWS creates with the VPC. Nothing here uses it - it is exposed so it can be locked down or referenced elsewhere."
  value       = module.vpc.default_security_group_id
}

output "availability_zones" {
  description = "Availability zones that ended up with at least one subnet."
  value       = module.vpc.availability_zones
}

########################################
# Subnets
########################################

output "subnet_ids" {
  description = "Subnet id per subnet key, where a key is \"<group>:<availability zone>\"."
  value       = module.vpc.subnet_ids
}

output "subnet_cidrs" {
  description = "CIDR per subnet key."
  value       = module.vpc.subnet_cidrs
}

output "subnet_names" {
  description = "Name tag per subnet key."
  value       = module.vpc.subnet_names
}

output "subnet_ids_by_group" {
  description = "Subnet ids per subnet group, ordered by availability zone."
  value       = module.vpc.subnet_ids_by_group
}

output "subnet_ids_by_az" {
  description = "Subnet ids per availability zone, across all groups."
  value       = module.vpc.subnet_ids_by_az
}

output "public_subnet_ids" {
  description = "Every subnet on a public tier, ordered by key."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Every subnet on a private tier, ordered by key."
  value       = module.vpc.private_subnet_ids
}

########################################
# Internet access
########################################

output "internet_gateway_id" {
  description = "Internet gateway id. Null when create_internet_gateway is false."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "NAT gateway id per availability zone. Empty with nat_gateway_mode = \"none\"."
  value       = module.vpc.nat_gateway_ids
}

output "nat_public_ips" {
  description = "Public IP of each NAT gateway, per availability zone - the addresses the private subnets appear as on the internet, and what a third party would allowlist."
  value       = module.vpc.nat_public_ips
}

output "public_route_table_id" {
  description = "Route table shared by the public subnets. Null when there are none."
  value       = module.vpc.public_route_table_id
}

output "private_route_table_ids" {
  description = "Private route table id per availability zone."
  value       = module.vpc.private_route_table_ids
}

########################################
# VPC endpoints
########################################

output "gateway_endpoint_ids" {
  description = "Gateway endpoint id per service short name."
  value       = module.vpc.gateway_endpoint_ids
}

output "interface_endpoint_ids" {
  description = "Interface endpoint id per service short name."
  value       = module.vpc.interface_endpoint_ids
}

output "interface_endpoint_dns_names" {
  description = "Regional DNS name of each interface endpoint. Only needed when interface_endpoint_private_dns is false - with private DNS on, clients keep using the public service hostname."
  value       = module.vpc.interface_endpoint_dns_names
}

output "interface_endpoint_subnet_ids" {
  description = "Subnets the interface endpoint ENIs were placed in - one per availability zone."
  value       = module.vpc.interface_endpoint_subnet_ids
}

output "vpc_endpoints_security_group_id" {
  description = "Security group allowing HTTPS to the interface endpoints. Null when no interface endpoint is configured."
  value       = module.vpc.vpc_endpoints_security_group_id
}

########################################
# Ready-made inputs for the other configurations
#
# So the ids the ec2 and eks-cluster tfvars need do not have to be copied out of
# the console or assembled by hand from the maps above. Both read the group
# names used in tf-example.tfvars ("pvt", "ctr", "pub") and fall back to an
# empty result when a group of that name does not exist, so renaming a group
# only empties the matching entry instead of failing the plan.
########################################

output "ec2_subnet_ids" {
  description = "Drop-in value for the subnet_ids map of the ec2 configuration: \"<group>-<az suffix>\" -> subnet id."
  value = {
    for k, id in module.vpc.subnet_ids :
    "${split(":", k)[0]}-${element(split("-", split(":", k)[1]), length(split("-", split(":", k)[1])) - 1)}" => id
  }
}

output "eks_cluster_inputs" {
  description = "Drop-in values for the eks-cluster configuration - vpc_id, vpc_cidr and the three subnet lists it expects."
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr
    ctr_subnet_ids        = lookup(module.vpc.subnet_ids_by_group, "ctr", [])
    private_ng_subnet_ids = lookup(module.vpc.subnet_ids_by_group, "pvt", [])
    public_subnet_ids     = lookup(module.vpc.subnet_ids_by_group, "pub", [])
  }
}
