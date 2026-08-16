########################################
# NAT gateways
#
# One per entry of local.nat_azs, which nat_gateway_mode reduces to nothing, to
# a single AZ, or to every AZ that has a public subnet. Keying them by AZ rather
# than by index means switching from "single" to "one_per_az" adds gateways in
# the other AZs and leaves the existing one in place.
########################################

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  # `domain = "vpc"` replaced the deprecated `vpc = true` in provider 5.x.
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-${local.az_suffix[each.value]}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.this[local.nat_host_subnet_by_az[each.value]].id

  tags = {
    Name = "${var.name_prefix}-nat-${local.az_suffix[each.value]}"
  }

  # A NAT gateway reaches the internet through the internet gateway, and AWS
  # does not infer that from the arguments - without this the gateway can be
  # created before its own route out exists.
  depends_on = [aws_internet_gateway.this]
}
