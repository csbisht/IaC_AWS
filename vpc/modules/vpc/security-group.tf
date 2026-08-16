########################################
# Interface endpoint security group
#
# An interface endpoint is an ENI in your subnets, and an ENI without a security
# group of its own lands in the VPC default group - which usually allows nothing
# from the instances that are meant to use it, so the endpoint resolves and then
# times out. This group is what makes the endpoints actually reachable.
#
# Created only when there is at least one interface endpoint; gateway endpoints
# are route table entries and need no security group.
########################################

resource "aws_security_group" "vpc_endpoints" {
  count = length(var.interface_endpoints) > 0 ? 1 : 0

  name_prefix = "${var.name_prefix}-vpc-endpoints-"
  description = "HTTPS to the interface VPC endpoints of ${local.vpc_name}"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the configured sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.endpoint_ingress_cidrs
  }

  # No egress rule on purpose. An endpoint ENI only answers requests, it never
  # opens a connection of its own, so the empty egress set that terraform
  # applies here (instead of the AWS default allow-all) costs nothing.

  tags = {
    Name = "${var.name_prefix}-vpc-endpoints"
  }

  # name_prefix plus create_before_destroy, so a rule change that forces
  # replacement can build the new group before the endpoints let go of the old.
  lifecycle {
    create_before_destroy = true
  }
}
