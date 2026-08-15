module "ec2" {
  source = "./modules/ec2"

  # Naming
  name_prefix = var.name_prefix

  # Existing network - nothing below is created, only looked up and used
  vpc_id     = var.vpc_id
  vpc_cidr   = var.vpc_cidr
  subnet_ids = var.subnet_ids

  # Security group
  create_security_group = var.create_security_group
  sg_ingress_rules      = var.sg_ingress_rules
  sg_egress_rules       = var.sg_egress_rules

  # Existing security groups
  enable_additional_security_groups = var.enable_additional_security_groups
  additional_security_groups        = var.additional_security_groups

  # IAM
  create_instance_profile = var.create_instance_profile
  instance_profile_name   = var.instance_profile_name
  iam_role_name           = var.iam_role_name
  enable_ssm              = var.enable_ssm
  enable_cloudwatch_agent = var.enable_cloudwatch_agent
  instance_policy_arns    = var.instance_policy_arns

  # Images
  ami_ids            = var.ami_ids
  ami_ssm_parameters = var.ami_ssm_parameters

  # Instance defaults
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.monitoring
  disable_api_termination     = var.disable_api_termination
  root_volume_size            = var.root_volume_size
  root_volume_type            = var.root_volume_type
  root_volume_encrypted       = var.root_volume_encrypted
  kms_key_id_ebs              = var.kms_key_id_ebs
  metadata_hop_limit          = var.metadata_hop_limit
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  # The instances themselves
  instances = var.instances
}
