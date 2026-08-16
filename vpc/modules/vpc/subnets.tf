########################################
# Subnets
#
# One resource for every tier, keyed "<group>:<availability zone>" - the layout
# is data in var.subnet_groups rather than a block per subnet, so adding an AZ
# or a tier is one line in the tfvars and touches nothing that already exists.
########################################

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # Only decides whether an instance launched here gets a public IP by default.
  # It is the route table that makes a subnet public, not this flag.
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = each.value.tags
}
