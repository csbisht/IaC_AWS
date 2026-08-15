########################################
# Existing network
#
# Both lookups are reads, never writes: nothing in this module creates or
# modifies a VPC or a subnet. They exist so that a wrong id is an error on
# `terraform plan` - with a message naming the id - instead of an
# InvalidSubnetID.NotFound half way through an apply that has already created
# the security group and the IAM role.
########################################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Only the subnets actually referenced by an instance are read, so an unused
# entry left behind in subnet_ids costs nothing and breaks nothing.
data "aws_subnet" "selected" {
  for_each = local.subnet_ids_in_use

  id = each.value

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "Subnet ${self.id} belongs to VPC ${self.vpc_id}, not to the configured vpc_id ${var.vpc_id}."
    }
  }
}
