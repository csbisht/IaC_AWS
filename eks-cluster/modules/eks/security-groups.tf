locals {
  # Placeholder tokens accepted inside `cidr_blocks` of the *_sg_ingress_rules /
  # *_sg_egress_rules variables. A tfvars file cannot reference another
  # variable, so a rule that has to follow var.vpc_cidr writes "@vpc_cidr"
  # instead. Anything that is not a token is passed through untouched, so
  # literal CIDRs keep working.
  sg_cidr_tokens = {
    "@vpc_cidr" = var.vpc_cidr
  }

  # Same idea for `security_group_ids`. Only the additional control plane
  # security group is resolvable: adding worker_nodes_sg here would make this
  # local depend on both security groups while both security groups depend on
  # the local, and terraform would reject the graph as a cycle. Rules on
  # cluster_additional_security_group therefore only accept literal sg-... ids,
  # which is also why they are expanded through a separate local below.
  sg_id_tokens = {
    "@cluster_additional_sg" = aws_security_group.cluster_additional_security_group.id
  }

  cluster_additional_sg_ingress = [
    for r in var.cluster_additional_sg_ingress_rules : merge(r, {
      cidr_blocks = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
    })
  ]

  cluster_additional_sg_egress = [
    for r in var.cluster_additional_sg_egress_rules : merge(r, {
      cidr_blocks = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
    })
  ]

  worker_nodes_sg_ingress = [
    for r in var.worker_nodes_sg_ingress_rules : merge(r, {
      cidr_blocks        = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
      security_group_ids = [for s in r.security_group_ids : lookup(local.sg_id_tokens, s, s)]
    })
  ]

  worker_nodes_sg_egress = [
    for r in var.worker_nodes_sg_egress_rules : merge(r, {
      cidr_blocks        = [for c in r.cidr_blocks : lookup(local.sg_cidr_tokens, c, c)]
      security_group_ids = [for s in r.security_group_ids : lookup(local.sg_id_tokens, s, s)]
    })
  ]
}

resource "aws_security_group" "cluster_additional_security_group" {
  name_prefix = "${var.cluster_name}-additional_sg-"
  description = "EKS Additional Security Group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.cluster_additional_sg_ingress
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
    for_each = local.cluster_additional_sg_egress
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
    Name = "${var.cluster_name}-additional_sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "worker_nodes_sg" {
  name_prefix = "${var.cluster_name}-nodegroup_sg-"
  description = "EKS NodeGroup Security Group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.worker_nodes_sg_ingress
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
    for_each = local.worker_nodes_sg_egress
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
    Name = "${var.cluster_name}-nodegroup_sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
