locals {
  # The two per-OS objects, flattened into maps so they can be indexed with an
  # instance's `os` string.
  ami_ids_by_os = {
    linux   = var.ami_ids.linux
    windows = var.ami_ids.windows
  }

  ami_ssm_by_os = {
    linux   = var.ami_ssm_parameters.linux
    windows = var.ami_ssm_parameters.windows
  }

  user_data_by_os = {
    linux   = var.user_data.linux
    windows = var.user_data.windows
  }

  # Expand group configurations in var.instances into individual instances.
  # Handles enable (true/false), count, and comma-separated names.
  expanded_instances = flatten([
    for group_key, cfg in var.instances : [
      for idx in range((cfg.enable != false) ? (cfg.count != null ? cfg.count : 1) : 0) : [
        for names in [[for n in split(",", cfg.name != null ? cfg.name : "") : trimspace(n) if trimspace(n) != ""]] : {
          group_key = group_key
          idx       = idx
          cfg       = cfg
          inst_key = (
            length(names) > idx ? names[idx] : (
              length(names) == 1 ? (
                (cfg.count != null ? cfg.count : 1) == 1 ? names[0] : "${names[0]}-${idx + 1}"
                ) : (
                (cfg.count != null ? cfg.count : 1) == 1 ? group_key : "${group_key}-${idx + 1}"
              )
            )
          )
        }
      ]
    ]
  ])

  # An SSM lookup happens only for an operating system that is in use and has
  # no id anywhere: with ami_ids filled in for both, or with every instance
  # pinning its own, no lookup is made at all.
  os_needing_default_ami = toset([
    for key, cfg in var.instances : cfg.os
    if(cfg.enable != false) && (cfg.count == null || cfg.count > 0) && (cfg.ami_id == null || cfg.ami_id == "") && local.ami_ids_by_os[cfg.os] == ""
  ])

  default_ami_ids = {
    for os, param in data.aws_ssm_parameter.default_ami : os => param.insecure_value
  }

  ########################################
  # Subnets
  #
  # Resolved from variables alone, with no dependency on the data sources in
  # network.tf - those take their for_each from this map, so it has to be known
  # before any lookup happens.
  ########################################

  instance_subnet_ids = {
    for key, cfg in local.instances : key => cfg.subnet_id
  }

  subnet_ids_in_use = {
    for id in distinct([for id in values(local.instance_subnet_ids) : id if id != ""]) : id => id
  }

  # Typed once in vpc_cidr, or read back from the VPC when that is left empty.
  vpc_cidr = var.vpc_cidr != "" ? var.vpc_cidr : data.aws_vpc.selected.cidr_block

  ########################################
  # Instances
  ########################################

  # Per-instance settings, resolved against the module-wide defaults. An
  # attribute left null in var.instances falls back to the matching var.*, so
  # the tfvars file only has to spell out what differs between instances.
  instances = {
    for item in local.expanded_instances : item.inst_key => {
      name          = "${var.name_prefix}-${item.inst_key}"
      os            = item.cfg.os
      subnet_key    = item.cfg.subnet_key
      subnet_id     = item.cfg.subnet_id != "" ? item.cfg.subnet_id : lookup(var.subnet_ids, item.cfg.subnet_key, "")
      instance_type = item.cfg.instance_type != null ? item.cfg.instance_type : var.instance_type

      # Instance pin first, then the per-OS id, then the per-OS SSM lookup.
      # coalesce skips both null and "", and try() turns "nothing left" into a
      # null that the precondition in instances.tf reports properly.
      ami_id = try(
        coalesce(
          item.cfg.ami_id,
          local.ami_ids_by_os[item.cfg.os],
          lookup(local.default_ami_ids, item.cfg.os, null),
        ),
        null,
      )

      key_name                    = item.cfg.key_name != null ? item.cfg.key_name : var.key_name
      private_ip                  = item.cfg.private_ip != null && item.cfg.private_ip != "" ? (item.idx == 0 ? item.cfg.private_ip : null) : null
      associate_public_ip_address = item.cfg.associate_public_ip_address != null ? item.cfg.associate_public_ip_address : var.associate_public_ip_address
      associate_eip               = item.cfg.associate_eip
      security_group_ids          = item.cfg.security_group_ids
      monitoring                  = item.cfg.monitoring != null ? item.cfg.monitoring : var.monitoring
      disable_api_termination     = item.cfg.disable_api_termination != null ? item.cfg.disable_api_termination : var.disable_api_termination
      root_volume_size            = item.cfg.root_volume_size != null ? item.cfg.root_volume_size : var.root_volume_size
      root_volume_type            = item.cfg.root_volume_type != null ? item.cfg.root_volume_type : var.root_volume_type
      user_data                   = item.cfg.user_data != null ? item.cfg.user_data : local.user_data_by_os[item.cfg.os]
      ebs_volumes                 = item.cfg.ebs_volumes
      tags                        = item.cfg.tags
    }
  }

  ########################################
  # Security groups
  ########################################

  # The pre-existing groups, split by how they were given: an id is used as is,
  # a name has to be looked up in security-group.tf.
  additional_sgs = var.enable_additional_security_groups ? var.additional_security_groups : []

  additional_sg_ids = [for sg in local.additional_sgs : sg.id if sg.id != ""]

  additional_sg_names = {
    for sg in local.additional_sgs : sg.name => sg.name if sg.id == ""
  }

  # Attached to every instance: the group created here (when
  # create_security_group is true), plus the pre-existing ones. The splat
  # collapses to [] on its own when the group is not created, which a
  # conditional indexing [0] would not - both branches of a conditional are
  # evaluated.
  common_security_group_ids = concat(
    aws_security_group.instances[*].id,
    local.additional_sg_ids,
    [for sg in data.aws_security_group.additional : sg.id],
  )

  ########################################
  # Storage
  ########################################

  # Additional data volumes, flattened from list-per-instance into one map so
  # each volume is an independent resource instance. The key is
  # "<instance key>:<device name>", which stays stable as long as neither the
  # instance nor the device is renamed.
  ebs_volumes = merge([
    for key, cfg in local.instances : {
      for vol in cfg.ebs_volumes : "${key}:${vol.device_name}" => {
        instance_key = key
        name         = "${cfg.name}-${replace(trimprefix(vol.device_name, "/"), "/", "-")}"
        device_name  = vol.device_name
        size         = vol.size
        type         = vol.type
        iops         = vol.iops
        throughput   = vol.throughput
      }
    }
  ]...)

  eip_instances = {
    for key, cfg in local.instances : key => cfg if cfg.associate_eip
  }

  # Empty string means "AWS managed aws/ebs key"; the argument has to be unset
  # for that, not set to "".
  ebs_kms_key_id = var.kms_key_id_ebs != "" ? var.kms_key_id_ebs : null
}

data "aws_ssm_parameter" "default_ami" {
  for_each = local.os_needing_default_ami

  name = local.ami_ssm_by_os[each.value]
}
