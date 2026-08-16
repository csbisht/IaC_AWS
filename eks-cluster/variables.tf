# Root variable interface. Deliberately identical to the pre-module interface so
# existing *.tfvars files keep working unchanged; main.tf forwards these into
# modules/eks. Validation is repeated in the module so it also holds for anyone
# consuming modules/eks directly.

########################################
# State backend
########################################

variable "use_s3_backend" {
  type        = bool
  description = <<-EOT
    Select where state is stored.

      true  - remote S3 backend, configured from a -backend-config file
              (see tf_config_example.tfvars).
      false - local state in ./terraform.tfstate.

    Read at init time by tf-init.ps1 / tf-init.sh, NOT by terraform itself:
    backend blocks are resolved before variables exist, so no backend block can
    reference this value. It is declared here only so that setting it in a
    *.tfvars file does not raise an "undeclared variable" warning, and so the
    intended backend is visible in the same file as the rest of the config.
    Changing it has no effect on plan or apply - only on the next init.
  EOT
  default     = false
}

########################################
# Core / networking
########################################

variable "aws_region" {
  type        = string
  description = "AWS region the cluster is deployed into. Consumed by the provider in providers.tf."
}

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

# Rule sets for the two security groups created by modules/eks. Every rule is
# an object mirroring the arguments of an inline aws_security_group rule block,
# with two placeholder tokens so a *.tfvars file can point at values that only
# exist at plan time:
#
#   cidr_blocks        "@vpc_cidr"              -> var.vpc_cidr
#   security_group_ids "@cluster_additional_sg" -> id of the additional
#                                                  control plane security group
#
# Tokens are only expanded in the worker node rules (see the note in
# modules/eks/security-groups.tf); rules on the additional security group
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

variable "eks_secrets_encryption_enabled" {
  type        = bool
  description = "Enable envelope encryption of Kubernetes secrets with the customer managed key in kms_key_arn_eks. Requires kms:CreateGrant on that key for the principal running terraform."
  default     = true
}

variable "kms_key_arn_eks" {
  type        = string
  description = "KMS key ARN used for envelope encryption of Kubernetes secrets. Ignored, and safe to leave empty, when eks_secrets_encryption_enabled is false."
  default     = ""
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
    the cluster is created with bootstrap_cluster_creator_admin_permissions =
    true, so that principal already holds cluster admin without an entry of its
    own. Set it to true to add a separate role (a break-glass role, an SSO
    permission set, a CI role) and supply eks_admin_role_arn.
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

########################################
# Add-ons
#
# Every add-on is off by default, so a config that only ever created a cluster
# keeps planning as an empty diff after the eks_add-ons merge. Turn the ones you
# want on in your *.tfvars file.
#
# There is no cluster_name variable here: the add-ons are handed
# module.eks.cluster_name ("<cluster_name>-eks"), the same string the old
# standalone eks_add-ons root asked you to repeat.
#
# Chart versions default to "", which installs whatever the repository serves as
# latest. Pin them per environment unless you want an unrelated apply to upgrade
# an add-on.
########################################

# --- AWS Load Balancer Controller ---

variable "enable_lbc" {
  description = "Deploy the AWS Load Balancer Controller."
  type        = bool
  default     = false
}

variable "lb_namespace" {
  description = "The Kubernetes namespace to install AWS LoadBalancer controller"
  type        = string
  default     = "kube-system"
}

variable "lb_sa_name" {
  type        = string
  description = "Service Account name for Load Balancer Controller."
  default     = "aws-load-balancer-controller"

  validation {
    condition     = length(regexall("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.lb_sa_name)) > 0
    error_message = "The service account name must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character."
  }
}

variable "lb-controller_chart_repository" {
  description = "The Helm chart repository URL for AWS Load Balancer Controller"
  type        = string
  default     = "https://aws.github.io/eks-charts"
}

variable "lb_chart_version" {
  description = "The version of the AWS LoadBalancer controller Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

# --- Amazon EBS CSI Driver ---

variable "enable_ebs" {
  description = "Deploy the Amazon EBS CSI Driver."
  type        = bool
  default     = false
}

variable "ebs_csi_namespace" {
  description = "The Kubernetes namespace to install AWS ebs csi Controller"
  type        = string
  default     = "kube-system"
}

variable "ebs_sa_name" {
  description = "The name of the Kubernetes service account for the EBS CSI Driver"
  type        = string
  default     = "ebs-csi-controller-sa"

  validation {
    condition     = length(regexall("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.ebs_sa_name)) > 0
    error_message = "The service account name must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character."
  }
}

variable "ebs_chart_repository" {
  description = "The Helm chart repository URL for AWS EBS CSI Driver"
  type        = string
  default     = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
}

variable "ebs_chart_version" {
  description = "The version of the AWS EBS CSI Driver Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

# --- Amazon VPC CNI ---

variable "enable_vpc_cni" {
  description = <<-EOT
    Deploy the Amazon VPC CNI plugin through Helm.

    Off by default, and rightly so on a stock cluster: EKS already installs the
    aws-node DaemonSet and its "aws-node" service account, which this module
    would then try to create a second time. Only turn it on when you have
    removed (or imported) the built-in objects, or when vpc_cni_sa_name points
    at a service account of your own.
  EOT
  type        = bool
  default     = false
}

variable "vpc_cni_namespace" {
  description = "The Kubernetes namespace to install AWS VPC CNI Controller"
  type        = string
  default     = "kube-system"
}

variable "vpc_cni_sa_name" {
  description = "The name of the Kubernetes service account for the VPC CNI plugin"
  type        = string
  default     = "aws-node"
}

variable "vpc_cni_chart_version" {
  description = "The version of the aws-vpc-cni Helm chart to install. Leave empty to use the latest version."
  type        = string
  default     = ""
}

# --- Metrics Server ---

variable "enable_metrics_server" {
  description = "Deploy the Metrics Server."
  type        = bool
  default     = false
}

variable "metrics_server_namespace" {
  description = "The Kubernetes namespace to install Metrics Server"
  type        = string
  default     = "kube-system"
}

variable "metrics_server_chart_repository" {
  description = "The Helm chart repository URL for Metrics Server"
  type        = string
  default     = "https://kubernetes-sigs.github.io/metrics-server"
}

variable "metrics_server_chart_name" {
  description = "The name of the Metrics Server Helm chart"
  type        = string
  default     = "metrics-server"
}

variable "metrics_server_chart_version" {
  description = "The version of the Metrics Server Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "metrics_server_release_name" {
  description = "The release name for the Helm deployment"
  type        = string
  default     = "metrics-server"
}

variable "metrics_server_service_account_name" {
  description = "The name of the Kubernetes service account for the Metrics Server"
  type        = string
  default     = "metrics-server"
}

# --- Cluster Autoscaler ---

variable "enable_cluster_autoscaler" {
  description = "Deploy the Cluster Autoscaler."
  type        = bool
  default     = false
}

variable "cluster_autoscaler_namespace" {
  description = "The namespace for the Cluster Autoscaler deployment"
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_release_name" {
  description = "The Helm release name for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_repository" {
  description = "The Helm chart repository for Cluster Autoscaler"
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
}

variable "cluster_autoscaler_chart_name" {
  description = "The Helm chart name for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_version" {
  description = "The version of the Cluster Autoscaler Helm chart to install. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "cluster_autoscaler_sa_name" {
  description = "The name of the service account for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}
