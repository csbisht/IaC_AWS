########################################
# Static public addresses
#
# associate_eip = true allocates an Elastic IP and associates it, giving the
# instance an address that survives a stop/start - unlike the auto-assigned
# public IP behind associate_public_ip_address, which changes on every stop.
#
# An Elastic IP only reaches the instance if the subnet routes to an internet
# gateway. In a private subnet the allocation succeeds and the address stays
# unreachable, and an EIP not attached to a running instance is billed.
########################################

resource "aws_eip" "instances" {
  for_each = local.eip_instances

  domain = "vpc"

  tags = {
    Name = "${each.value.name}-eip"
  }

  # The EIP itself does not depend on the instance, only the association does.
  # Allocating first keeps the address stable across an instance replacement.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip_association" "instances" {
  for_each = local.eip_instances

  allocation_id = aws_eip.instances[each.key].id
  instance_id   = aws_instance.instances[each.key].id
}
