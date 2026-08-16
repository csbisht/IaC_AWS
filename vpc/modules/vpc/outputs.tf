########################################
# VPC
########################################

output "vpc_id" {
  description = "Id of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the created VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr" {
  description = "IPv4 CIDR of the created VPC."
  value       = aws_vpc.this.cidr_block
}

output "vpc_name" {
  description = "Name tag of the created VPC."
  value       = local.vpc_name
}

output "default_security_group_id" {
  description = "The security group AWS creates with the VPC. Nothing here uses it - it is exposed so it can be locked down or referenced elsewhere."
  value       = aws_vpc.this.default_security_group_id
}

output "availability_zones" {
  description = "Availability zones that ended up with at least one subnet."
  value       = sort(local.all_azs)
}

########################################
# Subnets
########################################

output "subnet_ids" {
  description = "Subnet id per subnet key, where a key is \"<group>:<availability zone>\"."
  value       = { for k, s in aws_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  description = "CIDR per subnet key."
  value       = { for k, s in aws_subnet.this : k => s.cidr_block }
}

output "subnet_ids_by_group" {
  description = "Subnet ids per subnet group, ordered by availability zone. This is the shape the eks-cluster configuration wants for ctr_subnet_ids, private_ng_subnet_ids and public_subnet_ids."
  value = {
    for gk, g in local.enabled_groups :
    gk => [
      for k in sort(keys({ for sk, s in local.subnets : sk => s if s.group == gk })) :
      aws_subnet.this[k].id
    ]
  }
}

output "subnet_ids_by_az" {
  description = "Subnet ids per availability zone, across all groups."
  value = {
    for az in sort(local.all_azs) :
    az => [
      for k in sort(keys({ for sk, s in local.subnets : sk => s if s.az == az })) :
      aws_subnet.this[k].id
    ]
  }
}

output "public_subnet_ids" {
  description = "Every subnet on a public tier, ordered by key."
  value       = [for k in sort(keys(local.public_subnets)) : aws_subnet.this[k].id]
}

output "private_subnet_ids" {
  description = "Every subnet on a private tier, ordered by key."
  value       = [for k in sort(keys(local.private_subnets)) : aws_subnet.this[k].id]
}

output "subnet_names" {
  description = "Name tag per subnet key."
  value       = { for k, s in local.subnets : k => s.name }
}

########################################
# Internet access
########################################

output "internet_gateway_id" {
  description = "Internet gateway id. Null when create_internet_gateway is false."
  value       = one(aws_internet_gateway.this[*].id)
}

output "nat_gateway_ids" {
  description = "NAT gateway id per availability zone. Empty with nat_gateway_mode = \"none\"."
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}

output "nat_public_ips" {
  description = "Public IP of each NAT gateway, per availability zone - the addresses the private subnets appear as on the internet, and what a third party would allowlist."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "public_route_table_id" {
  description = "Route table shared by the public subnets. Null when there are none."
  value       = one(aws_route_table.public[*].id)
}

output "private_route_table_ids" {
  description = "Private route table id per availability zone."
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

########################################
# VPC endpoints
########################################

output "gateway_endpoint_ids" {
  description = "Gateway endpoint id per service short name."
  value       = { for s, e in aws_vpc_endpoint.gateway : s => e.id }
}

output "interface_endpoint_ids" {
  description = "Interface endpoint id per service short name."
  value       = { for s, e in aws_vpc_endpoint.interface : s => e.id }
}

output "interface_endpoint_dns_names" {
  description = "Regional DNS name of each interface endpoint. Only needed when interface_endpoint_private_dns is false - with private DNS on, clients keep using the public service hostname."
  value = {
    for s, e in aws_vpc_endpoint.interface :
    s => [for entry in e.dns_entry : entry.dns_name]
  }
}

output "interface_endpoint_subnet_ids" {
  description = "Subnets the interface endpoint ENIs were placed in - one per availability zone."
  value       = [for k in local.interface_endpoint_subnet_keys : aws_subnet.this[k].id]
}

output "vpc_endpoints_security_group_id" {
  description = "Security group allowing HTTPS to the interface endpoints. Null when no interface endpoint is configured."
  value       = one(aws_security_group.vpc_endpoints[*].id)
}
