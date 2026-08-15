########################################
# Core / networking
########################################

variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC hosting the cluster."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC, used to scope worker node security group ingress."
}

variable "ctr_subnet_ids" {
  type        = list(string)
  description = "Subnets for the EKS control plane ENIs. Must span at least two AZs."

  validation {
    condition     = length(var.ctr_subnet_ids) >= 2
    error_message = "EKS requires control plane subnets in at least two availability zones."
  }
}

variable "private_ng_subnet_ids" {
  type        = list(string)
  description = "Private subnets the managed node group launches instances into."

  validation {
    condition     = length(var.private_ng_subnet_ids) > 0
    error_message = "At least one node group subnet must be provided."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets tagged for internet-facing load balancer discovery."
  default     = []
}

########################################
# Security groups
########################################

# Rule sets for the two security groups created by this module. Every rule is
# an object mirroring the arguments of an inline aws_security_group rule block,
# with two placeholder tokens so a *.tfvars file can point at values that only
# exist at plan time:
#
#   cidr_blocks        "@vpc_cidr"              -> var.vpc_cidr
#   security_group_ids "@cluster_additional_sg" -> id of the additional
#                                                  control plane security group
#
# Tokens are only expanded in the rules of aws_security_group.worker_nodes_sg
# (see the note in security-groups.tf); rules on the additional security group
# expand "@vpc_cidr" but take literal sg-... ids only. Every other entry is
# passed through unchanged, so literal CIDRs and security group ids work as
# usual. An empty list removes all rules of that direction.

variable "cluster_additional_sg_ingress_rules" {
  description = "Ingress rules of the additional security group attached to the control plane ENIs."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description = "Kubernetes API from inside the VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["@vpc_cidr"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.cluster_additional_sg_ingress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one source: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

variable "cluster_additional_sg_egress_rules" {
  description = "Egress rules of the additional security group attached to the control plane ENIs."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description = "allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.cluster_additional_sg_egress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one destination: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

variable "worker_nodes_sg_ingress_rules" {
  description = "Ingress rules of the security group attached to worker node ENIs."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description        = "NodePort range from the cluster security group"
      from_port          = 30000
      to_port            = 32767
      protocol           = "tcp"
      security_group_ids = ["@cluster_additional_sg"]
    },
    {
      description = "allow VPC traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["@vpc_cidr"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.worker_nodes_sg_ingress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one source: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

variable "worker_nodes_sg_egress_rules" {
  description = "Egress rules of the security group attached to worker node ENIs."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description = "allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.worker_nodes_sg_egress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one destination: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

########################################
# Cluster
########################################

variable "cluster_name" {
  type        = string
  description = "Base name of the cluster. The suffix '-eks' is appended to it."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes control plane version, e.g. \"1.33\"."
}

variable "iam_role_name" {
  type        = string
  description = "Base name used to build the cluster and node group IAM role names."
}

variable "kms_key_arn_eks" {
  type        = string
  description = "KMS key ARN used for envelope encryption of Kubernetes secrets."
}

variable "kms_key_id_ebs" {
  type        = string
  description = "KMS key ARN used to encrypt worker node EBS root volumes."
}

variable "eks_cluster_logging_enabled" {
  type        = bool
  description = "Enable or disable EKS control-plane logging to CloudWatch."
  default     = true
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Expose the Kubernetes API endpoint publicly. Keep false for private-only clusters."
  default     = false
}

########################################
# Node group
########################################

variable "deploy_eks_nodegroup" {
  type        = bool
  description = "Control deployment of the managed node group."
  default     = true
}

variable "node_group_name" {
  type        = string
  description = "Name of the managed node group."
}

variable "node_group_version" {
  type        = string
  description = "Kubernetes version of the node group. Must not be newer than cluster_version."
}

variable "node_group_desired_capacity" {
  type        = number
  description = "Desired number of worker nodes."
}

variable "node_group_max_capacity" {
  type        = number
  description = "Maximum number of worker nodes."
}

variable "node_group_min_capacity" {
  type        = number
  description = "Minimum number of worker nodes."
}

variable "instance_type" {
  type        = list(string)
  description = "Candidate EC2 instance types for the node group."

  validation {
    condition     = length(var.instance_type) > 0
    error_message = "At least one instance type must be provided."
  }
}

variable "ami_type" {
  type        = string
  description = "EKS AMI type, e.g. AL2023_x86_64_STANDARD."
}

variable "disk_size" {
  type        = number
  description = "Root EBS volume size in GiB for worker nodes."
}

variable "ssh_key_name" {
  type        = string
  description = "EC2 key pair name attached to worker nodes. Leave empty to disable SSH key injection."
  default     = ""
}

variable "enable_nodegroup_labels" {
  type        = bool
  description = "Enable/disable nodegroup labels."
  default     = false
}

variable "nodegroup_labels" {
  type        = map(string)
  description = "Labels to apply to the nodegroup."
  default     = {}
}

variable "enable_nodegroup_taints" {
  type        = bool
  description = "Enable/disable nodegroup taints."
  default     = false
}

variable "nodegroup_taints" {
  description = "Taints to apply to the nodegroup."
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []

  validation {
    condition = alltrue([
      for t in var.nodegroup_taints :
      contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], t.effect)
    ])
    error_message = "Taint effect must be one of NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE."
  }
}

########################################
# Cluster admin access
########################################

variable "enable_eks_admin_access" {
  type        = bool
  description = <<-EOT
    Grant an existing IAM role cluster admin through an EKS access entry.

    Leave false when the principal running terraform is the only admin needed:
    cluster.tf sets bootstrap_cluster_creator_admin_permissions = true, so that
    principal already holds cluster admin without an entry of its own. Set it to
    true to add a separate role (a break-glass role, an SSO permission set, a CI
    role) and supply eks_admin_role_arn.
  EOT
  default     = false
}

variable "eks_admin_role_arn" {
  type        = string
  description = "IAM role ARN granted cluster admin through an EKS access entry. Required when enable_eks_admin_access is true, ignored otherwise."
  default     = ""
}

variable "eks_admin_name" {
  type        = string
  description = "Kubernetes username projected for the admin principal in the EKS access entry. Leave empty to let EKS derive it from the principal ARN."
  default     = ""
}
