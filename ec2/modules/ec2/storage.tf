########################################
# Additional data volumes
#
# Kept out of the instance resource on purpose: an aws_instance ebs_block_device
# is part of the instance, so growing or retyping one drags the whole instance
# through a replacement. A standalone volume plus an attachment can be resized
# in place, survives an instance replacement, and can be detached and moved.
#
# The volumes are created in the instance's availability zone, which is read
# back from the instance rather than asked for in the tfvars - EC2 refuses to
# attach a volume from another AZ, so there is nothing to get wrong here.
########################################

resource "aws_ebs_volume" "data" {
  for_each = local.ebs_volumes

  availability_zone = aws_instance.instances[each.value.instance_key].availability_zone
  size              = each.value.size
  type              = each.value.type

  # gp2 and standard take neither; gp3 defaults to 3000 IOPS / 125 MiB/s when
  # left null, io1 and io2 require iops.
  iops       = each.value.iops
  throughput = each.value.throughput

  encrypted  = true
  kms_key_id = local.ebs_kms_key_id

  tags = {
    Name = each.value.name
  }
}

resource "aws_volume_attachment" "data" {
  for_each = local.ebs_volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.data[each.key].id
  instance_id = aws_instance.instances[each.value.instance_key].id

  # Detaching a mounted volume by API is the equivalent of pulling the disk out:
  # the file system is not unmounted first. Left at the default (false) so a
  # destroy that cannot detach fails loudly instead of risking the data.
  force_detach = false
}
