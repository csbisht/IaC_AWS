resource "aws_vpc" "this" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = var.instance_tenancy

  # Both are needed for the private DNS names of interface endpoints, and EKS
  # refuses to create a cluster in a VPC that has them off.
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = local.vpc_name
  }

  # The VPC is the one resource that always exists, so the checks that concern
  # the configuration as a whole live here: they run on `terraform plan` and
  # name the variable to change, instead of failing half way through an apply
  # or - worse - quietly building a VPC that is missing a piece.
  lifecycle {
    precondition {
      condition     = var.nat_gateway_mode == "none" || length(local.public_azs) > 0
      error_message = "nat_gateway_mode = \"${var.nat_gateway_mode}\" needs a public subnet to put the NAT gateway in, but no enabled subnet group has tier = \"public\"."
    }

    precondition {
      condition     = var.nat_gateway_mode == "none" || var.create_internet_gateway
      error_message = "nat_gateway_mode = \"${var.nat_gateway_mode}\" needs create_internet_gateway = true - a NAT gateway reaches the internet through the internet gateway."
    }

    precondition {
      condition     = length(local.interface_endpoint_services) == 0 || local.interface_endpoint_group != ""
      error_message = "interface_endpoints are enabled but there is no subnet group to place their ENIs in. Add a group with tier = \"private\", or name one in interface_endpoint_subnet_group."
    }

    precondition {
      condition     = length(local.interface_endpoint_services) == 0 || length(local.interface_endpoint_subnet_keys) > 0
      error_message = "interface_endpoint_subnet_group = \"${local.interface_endpoint_group}\" is not an enabled subnet group with at least one CIDR, so the interface endpoints have nowhere to go."
    }

    precondition {
      condition     = length(local.interface_endpoint_services) == 0 || !var.interface_endpoint_private_dns || (var.enable_dns_support && var.enable_dns_hostnames)
      error_message = "interface_endpoint_private_dns = true needs both enable_dns_support and enable_dns_hostnames on the VPC."
    }

    precondition {
      condition     = length(local.gateway_endpoint_services) == 0 || length(local.private_azs) > 0
      error_message = "gateway_endpoints are enabled and are wired into the private route tables, but no enabled subnet group has tier = \"private\"."
    }
  }
}
