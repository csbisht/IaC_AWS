# for_each rather than count: with count, removing or reordering a subnet id in
# the tfvars shifts every later index and churns unrelated tags.

resource "aws_ec2_tag" "tag_existing_subnet_ctr" {
  for_each    = toset(var.ctr_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "tag_existing_subnet_nodegroup" {
  for_each    = toset(var.private_ng_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "tag_existing_subnet_public" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

# Required for AWS Load Balancer Controller subnet auto-discovery. Without
# these, Service type=LoadBalancer and Ingress provisioning fail to place ELBs.
resource "aws_ec2_tag" "tag_existing_subnet_nodegroup_internal_elb" {
  for_each    = toset(var.private_ng_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "tag_existing_subnet_public_elb" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
