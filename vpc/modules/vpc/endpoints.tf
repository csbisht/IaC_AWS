########################################
# Gateway endpoints (S3, DynamoDB)
#
# A gateway endpoint is a route, not an ENI: free, no security group, and it
# only applies to the route tables it is attached to. Attaching it to the
# private tables is what keeps S3 traffic off the NAT gateway.
########################################

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.gateway_endpoints)

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name = "${var.name_prefix}-${each.value}-endpoint"
  }
}

########################################
# Interface endpoints
#
# subnet_ids comes from local.interface_endpoint_subnet_keys, i.e. the subnets
# of one group - at most one per AZ. Anything that collects "all private
# subnets" instead hands AWS two subnets in the same AZ as soon as there is more
# than one private tier, and the endpoint is rejected with
# DuplicateSubnetsInSameZone.
#
# The ids are read from the aws_subnet resources rather than looked up with a
# data source, so a first apply works: a data source that filters on tags of
# subnets created in the same run has nothing to find when the plan is made.
########################################

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for k in local.interface_endpoint_subnet_keys : aws_subnet.this[k].id]
  security_group_ids  = aws_security_group.vpc_endpoints[*].id
  private_dns_enabled = var.interface_endpoint_private_dns

  tags = {
    Name = "${var.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
  }
}
