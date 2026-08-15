resource "aws_instance" "instances" {
  for_each = local.instances

  ami           = each.value.ami_id
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  key_name   = each.value.key_name != "" ? each.value.key_name : null
  private_ip = each.value.private_ip

  # On Windows the Administrator password is generated at first boot and
  # encrypted with the key pair. Asking for it here is what makes
  # `terraform output windows_password_data` (and the RDP login) possible at
  # all; without a key pair there is nothing to ask for.
  get_password_data = each.value.os == "windows" && each.value.key_name != ""

  vpc_security_group_ids = concat(local.common_security_group_ids, each.value.security_group_ids)
  iam_instance_profile   = local.instance_profile_name

  associate_public_ip_address = each.value.associate_public_ip_address
  monitoring                  = each.value.monitoring
  disable_api_termination     = each.value.disable_api_termination

  # Plain text in, base64 on the wire. user_data only ever runs on first boot,
  # which is why replacing the instance is opt-in through
  # user_data_replace_on_change rather than the default.
  user_data                   = each.value.user_data != "" ? each.value.user_data : null
  user_data_replace_on_change = var.user_data_replace_on_change

  root_block_device {
    volume_size           = each.value.root_volume_size
    volume_type           = each.value.root_volume_type
    delete_on_termination = true

    # Encryption at launch, from an unencrypted AMI snapshot as well. A handful
    # of older or marketplace AMIs reject it - set root_volume_encrypted =
    # false, or start from an already encrypted AMI, if a launch fails with
    # "Parameter encrypted is invalid".
    encrypted  = var.root_volume_encrypted
    kms_key_id = var.root_volume_encrypted ? local.ebs_kms_key_id : null

    tags = merge(each.value.tags, {
      Name = "${each.value.name}-root"
    })
  }

  metadata_options {
    http_endpoint = "enabled"
    # IMDSv2 only. IMDSv1's unauthenticated GET is what turns a request
    # forgery bug in an application into instance credentials.
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
    instance_metadata_tags      = "enabled"
  }

  tags = merge(each.value.tags, {
    Name = each.value.name
    OS   = each.value.os
  })

  lifecycle {
    # Both checks span two variables, which variable validation blocks only
    # support from terraform 1.9 while versions.tf allows >= 1.6.
    precondition {
      condition     = each.value.subnet_id != ""
      error_message = "Instance '${each.key}' has subnet_key = \"${each.value.subnet_key}\", which is not a key of subnet_ids. Add it there, or give the instance a literal subnet_id."
    }

    precondition {
      condition     = each.value.ami_id != null && each.value.ami_id != ""
      error_message = "No AMI for instance '${each.key}' (os = \"${each.value.os}\"): set ami_id on the instance, fill in ami_ids.${each.value.os}, or leave ami_ssm_parameters.${each.value.os} pointing at a readable public parameter."
    }
  }
}
