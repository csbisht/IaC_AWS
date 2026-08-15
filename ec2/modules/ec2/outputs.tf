output "instance_ids" {
  description = "Instance id per instance key."
  value       = { for k, i in aws_instance.instances : k => i.id }
}

output "instance_arns" {
  description = "Instance ARN per instance key."
  value       = { for k, i in aws_instance.instances : k => i.arn }
}

output "instance_names" {
  description = "Name tag per instance key."
  value       = { for k, i in local.instances : k => i.name }
}

output "instance_os" {
  description = "Operating system selected per instance key."
  value       = { for k, i in local.instances : k => i.os }
}

output "private_ips" {
  description = "Primary private IP per instance key."
  value       = { for k, i in aws_instance.instances : k => i.private_ip }
}

output "public_ips" {
  description = "Public IP per instance key. Empty for instances with neither a public IP nor an Elastic IP."
  value       = { for k, i in aws_instance.instances : k => i.public_ip }
}

output "availability_zones" {
  description = "Availability zone each instance landed in, derived from its subnet."
  value       = { for k, i in aws_instance.instances : k => i.availability_zone }
}

output "eip_public_ips" {
  description = "Elastic IP per instance key, for instances with associate_eip = true."
  value       = { for k, e in aws_eip.instances : k => e.public_ip }
}

output "ebs_volume_ids" {
  description = "Additional data volume ids, keyed by \"<instance key>:<device name>\"."
  value       = { for k, v in aws_ebs_volume.data : k => v.id }
}

output "windows_password_data" {
  description = "Encrypted Administrator password per Windows instance that was launched with a key pair. Decrypt with the matching private key: aws ec2 get-password-data --instance-id <id> --priv-launch-key <key>.pem"
  value = {
    for k, i in aws_instance.instances : k => i.password_data
    if local.instances[k].os == "windows" && local.instances[k].key_name != ""
  }
}

########################################
# Network and images actually used
########################################

output "vpc_id" {
  description = "The existing VPC the instances were placed in."
  value       = data.aws_vpc.selected.id
}

output "vpc_cidr" {
  description = "CIDR of that VPC, whether given in vpc_cidr or read back from AWS."
  value       = local.vpc_cidr
}

output "subnet_ids_used" {
  description = "Subnet each instance was placed in, per instance key."
  value       = local.instance_subnet_ids
}

output "ami_ids_used" {
  description = "AMI each instance was launched from, per instance key."
  value       = { for k, i in local.instances : k => i.ami_id }
}

output "ami_ids_from_ssm" {
  description = "AMI resolved from ami_ssm_parameters per operating system. Empty when nothing needed a lookup."
  value       = local.default_ami_ids
}

########################################
# Security and identity
########################################

output "security_group_id" {
  description = "Security group created for the instances. Null when create_security_group is false."
  value       = one(aws_security_group.instances[*].id)
}

output "additional_security_group_ids" {
  description = "Pre-existing security groups attached to every instance, ids given directly plus the ones resolved from a name. Empty when enable_additional_security_groups is false."
  value       = concat(local.additional_sg_ids, [for sg in data.aws_security_group.additional : sg.id])
}

output "security_group_ids_attached" {
  description = "Every security group attached to all instances - the created one and the pre-existing ones."
  value       = local.common_security_group_ids
}

output "iam_role_arn" {
  description = "ARN of the instance role. Null when create_instance_profile is false."
  value       = one(aws_iam_role.instances[*].arn)
}

output "iam_role_name" {
  description = "Name of the instance role. Null when create_instance_profile is false."
  value       = one(aws_iam_role.instances[*].name)
}

output "instance_profile_name" {
  description = "Instance profile attached to the instances, whether created here or passed in. Null when neither applies."
  value       = local.instance_profile_name
}
