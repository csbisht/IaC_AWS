########################################
# Route tables
#
# One shared table for the public tier - every public subnet wants the same
# single route to the internet gateway - and one table per availability zone for
# the private tier, so that a per-AZ NAT gateway can be routed to without moving
# any subnet between tables later.
#
# The default routes are separate aws_route resources rather than inline `route`
# blocks: an inline block makes the route table itself the unit of change, so
# every association churns when a route is added, and it also fights with any
# route written by something else (a transit gateway attachment, a peering) into
# the same table.
########################################

resource "aws_route_table" "public" {
  count = length(local.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public"
  }
}

resource "aws_route_table" "private" {
  for_each = toset(local.private_azs)

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-private-${local.az_suffix[each.value]}"
  }
}

########################################
# Default routes
########################################

resource "aws_route" "public_internet" {
  count = length(local.public_subnets) > 0 && var.create_internet_gateway ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# Only for the AZs that have a NAT gateway to point at: with
# nat_gateway_mode = "none" this is empty and the private tier is left with the
# local route alone.
resource "aws_route" "private_nat" {
  for_each = { for az, nat_az in local.nat_az_for_private_az : az => nat_az if nat_az != null }

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

########################################
# Associations
#
# A subnet with no association falls back to the VPC main route table, which
# this module never touches - so every subnet it creates is associated here
# explicitly, public or private.
########################################

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id = aws_subnet.this[each.key].id

  route_table_id = (
    each.value.public
    ? aws_route_table.public[0].id
    : aws_route_table.private[each.value.az].id
  )
}
