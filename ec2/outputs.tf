output "instance_ids" {
  description = "Instance id per instance key."
  value       = module.ec2.instance_ids
}

output "instance_arns" {
  description = "Instance ARN per instance key."
  value       = module.ec2.instance_arns
}

output "instance_names" {
  description = "Name tag per instance key."
  value       = module.ec2.instance_names
}

output "instance_os" {
  description = "Operating system selected per instance key."
  value       = module.ec2.instance_os
}

output "private_ips" {
  description = "Primary private IP per instance key."
  value       = module.ec2.private_ips
}

output "public_ips" {
  description = "Public IP per instance key. Empty for instances with neither a public IP nor an Elastic IP."
  value       = module.ec2.public_ips
}

output "eip_public_ips" {
  description = "Elastic IP per instance key, for instances with associate_eip = true."
  value       = module.ec2.eip_public_ips
}

output "availability_zones" {
  description = "Availability zone each instance landed in, derived from its subnet."
  value       = module.ec2.availability_zones
}

output "ebs_volume_ids" {
  description = "Additional data volume ids, keyed by \"<instance key>:<device name>\"."
  value       = module.ec2.ebs_volume_ids
}

########################################
# Existing network and images that were used
########################################

output "vpc_id" {
  description = "The existing VPC the instances were placed in."
  value       = module.ec2.vpc_id
}

output "vpc_cidr" {
  description = "CIDR of that VPC, whether given in vpc_cidr or read back from AWS."
  value       = module.ec2.vpc_cidr
}

output "subnet_ids_used" {
  description = "Subnet each instance was placed in, per instance key."
  value       = module.ec2.subnet_ids_used
}

output "ami_ids_used" {
  description = "AMI each instance was launched from, per instance key."
  value       = module.ec2.ami_ids_used
}

output "ami_ids_from_ssm" {
  description = "AMI resolved from ami_ssm_parameters per operating system. Empty when nothing needed a lookup - i.e. when every AMI is pinned."
  value       = module.ec2.ami_ids_from_ssm
}

########################################
# Security and identity
########################################

output "security_group_id" {
  description = "Security group created for the instances. Null when create_security_group is false."
  value       = module.ec2.security_group_id
}

output "additional_security_group_ids" {
  description = "Pre-existing security groups attached to every instance. Empty when enable_additional_security_groups is false."
  value       = module.ec2.additional_security_group_ids
}

output "security_group_ids_attached" {
  description = "Every security group attached to all instances - the created one and the pre-existing ones."
  value       = module.ec2.security_group_ids_attached
}

output "iam_role_arn" {
  description = "ARN of the instance role. Null when create_instance_profile is false."
  value       = module.ec2.iam_role_arn
}

output "instance_profile_name" {
  description = "Instance profile attached to the instances, whether created here or passed in."
  value       = module.ec2.instance_profile_name
}

########################################
# Ready-made connection commands
#
# So the things you actually do after an apply do not have to be assembled by
# hand out of the outputs above.
########################################

output "ssm_connect_commands" {
  description = "Session Manager command per instance - a shell on Linux, PowerShell on Windows. Needs enable_ssm = true, the SSM agent running and a route to the SSM endpoints."
  value = {
    for k, id in module.ec2.instance_ids :
    k => "aws ssm start-session --region ${var.aws_region} --target ${id}"
  }
}

output "windows_password_commands" {
  description = "How to recover the Administrator password of each Windows instance launched with a key pair. Needs the matching private key file."
  value = {
    for k, id in module.ec2.instance_ids :
    k => "aws ec2 get-password-data --region ${var.aws_region} --instance-id ${id} --priv-launch-key <your-key>.pem"
    if module.ec2.instance_os[k] == "windows"
  }
}

output "rdp_targets" {
  description = "Address to point an RDP client at, per Windows instance. Reachable from inside the VPC, or through Session Manager port forwarding."
  value = {
    for k, ip in module.ec2.private_ips :
    k => "${ip}:3389"
    if module.ec2.instance_os[k] == "windows"
  }
}
