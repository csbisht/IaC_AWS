locals {
  # Placeholder token accepted inside `cidr_blocks` of the sg_ingress_rules /
  # sg_egress_rules variables. A tfvars file cannot reference another variable,
  # so a rule that has to follow the VPC range writes "@vpc_cidr" instead.
  # Anything that is not a token is passed through untouched, so literal CIDRs
  # keep working.
  sg_cidr_tokens = {
    "@vpc_cidr" = local.vpc_cidr
  }

  # There is deliberately no "@instances_sg" token for security_group_ids: the
  # local would depend on the security group while the security group depends
  # on the local, and terraform rejects that graph as a cycle. Use `self = true`
  # for instance-to-instance traffic instead - it means the same thing and needs
  # no id.
  sg_ingress = [
    for r in var.sg_ingress_rules : merge(r, {
      cidr_blocks = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
    })
  ]

  sg_egress = [
    for r in var.sg_egress_rules : merge(r, {
      cidr_blocks = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
    })
  ]
}

########################################
# Pre-existing security groups, by name
#
# Entries of additional_security_groups that gave an id are used straight from
# the variable. Only the ones that gave a name reach this lookup, which is
# scoped to vpc_id so a name that exists in another VPC is not picked up by
# accident. A name with no match fails the plan.
########################################

data "aws_security_group" "additional" {
  for_each = local.additional_sg_names

  name   = each.value
  vpc_id = var.vpc_id
}

resource "aws_security_group" "instances" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.name_prefix}-ec2_sg-"
  description = "EC2 instance security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.sg_ingress
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      prefix_list_ids  = ingress.value.prefix_list_ids
      security_groups  = ingress.value.security_group_ids
      self             = ingress.value.self
    }
  }

  dynamic "egress" {
    for_each = local.sg_egress
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      prefix_list_ids  = egress.value.prefix_list_ids
      security_groups  = egress.value.security_group_ids
      self             = egress.value.self
    }
  }

  tags = {
    Name = "${var.name_prefix}-ec2_sg"
  }

  # name_prefix plus create_before_destroy, so a rule change that forces
  # replacement can build the new group before the instances let go of the old.
  lifecycle {
    create_before_destroy = true
  }
}
