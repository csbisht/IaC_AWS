# State backend selector, consumed by tf-init.ps1 / tf-init.sh at init time.
#   true  -> remote S3 backend, keys taken from the -backend-config file
#   false -> local state in ./terraform.tfstate
use_s3_backend = false

aws_region            = "eu-central-1"
vpc_id                = "vpc-1234567890"
vpc_cidr              = "172.35.0.0/19"
private_ng_subnet_ids = ["subnet-1111111111", "subnet-2222222222", "subnet-3333333333"]
ctr_subnet_ids        = ["subnet-1111111111", "subnet-2222222222", "subnet-3333333333"]
public_subnet_ids     = ["subnet-4444444444", "subnet-5555555555", "subnet-6666666666"]

# Security group rules. Each entry mirrors an inline aws_security_group rule:
#   description        optional, defaults to ""
#   from_port          required
#   to_port            required
#   protocol           required ("tcp", "udp", "icmp", "-1" for all)
#   cidr_blocks        optional, defaults to []
#   ipv6_cidr_blocks   optional, defaults to []
#   prefix_list_ids    optional, defaults to []
#   security_group_ids optional, defaults to []
#   self               optional, defaults to false
# At least one source/destination must be set per rule.
#
# Two placeholders stand in for values a tfvars file cannot reference:
#   "@vpc_cidr"              -> the value of vpc_cidr above
#   "@cluster_additional_sg" -> the additional security group created below,
#                               usable in the worker node rules only
# Anything else is taken literally, so "10.0.0.0/8" or "sg-0abc..." work too.
# Set a list to [] to create the security group with no rules in that direction.

cluster_additional_sg_ingress_rules = [
  {
    description = "Kubernetes API from inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["@vpc_cidr"]
  }
]

cluster_additional_sg_egress_rules = [
  {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

worker_nodes_sg_ingress_rules = [
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

worker_nodes_sg_egress_rules = [
  {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

cluster_name = "tf-example"
# Verify against `aws eks describe-cluster-versions` before use; standard
# support for a given minor version lasts roughly 14 months after release.
cluster_version = "1.33"
iam_role_name   = "tf-example"

# KMS key used to encrypt the worker node EBS root volumes. Always required,
# the launch template references it for every node.
kms_key_id_ebs = "arn:aws:kms:eu-central-1:123456789012:key/00000000-0000-0000-0000-000000000000"

# Envelope encryption of Kubernetes secrets (control-plane / etcd secrets) with
# a customer managed KMS key. EKS already encrypts etcd with an AWS owned key,
# so this is a second layer under a key you control - useful for compliance
# (PCI/HIPAA-style "CMK for secrets at rest" requirements), unnecessary for a
# throwaway or sandbox cluster.
#
# true requires kms_key_arn_eks below AND these permissions for the principal
# running terraform (and for the key policy to allow them):
#   kms:CreateGrant, kms:DescribeKey  on that key
# EKS creates a grant on the key at cluster creation time; missing CreateGrant
# is what produces:
#   InvalidRequestException: User not authorized to perform kms:CreateGrant
# Fix it by granting the permission, or set this to false to skip the feature.
#
# Note: this can be turned on for an existing cluster, but it cannot be turned
# off again - flipping true -> false on a live cluster replaces the cluster.
# Decide before the first apply.
eks_secrets_encryption_enabled = true

# Required only when eks_secrets_encryption_enabled = true, otherwise ignored
# and safe to leave empty. Must be a symmetric encryption key in the same
# region as the cluster.
kms_key_arn_eks = "arn:aws:kms:eu-central-1:123456789012:key/00000000-0000-0000-0000-000000000000"

eks_cluster_logging_enabled    = true
cluster_endpoint_public_access = false

deploy_eks_nodegroup        = true
node_group_name             = "tf-example"
node_group_version          = "1.33"
node_group_desired_capacity = 1
node_group_max_capacity     = 1
node_group_min_capacity     = 1
instance_type               = ["m5.large"]
ami_type                    = "AL2023_x86_64_STANDARD"
disk_size                   = 100
ssh_key_name                = "tf-example"

enable_nodegroup_labels = true
nodegroup_labels = {
  "env" = "app"
}

enable_nodegroup_taints = false
nodegroup_taints = [
  {
    key    = "tf-example.com/tier"
    value  = "tf-example"
    effect = "NO_EXECUTE"
  }
]

# Optional. The principal that runs terraform is made a cluster admin
# automatically, so leaving this false still gives you a usable cluster. Set it
# to true to grant a *second*, named IAM role cluster admin through an EKS
# access entry - pointing it at the applying principal itself collides with the
# automatic entry and fails with ResourceInUseException.
enable_eks_admin_access = false

# Required only when enable_eks_admin_access = true. Must be an IAM *role*;
# users and the account root are rejected.
eks_admin_role_arn = "arn:aws:iam::123456789012:role/eks-admin"

# Optional even when access is enabled. Empty lets EKS derive the Kubernetes
# username from the principal ARN; set it to keep audit-log subjects and any
# existing RBAC bindings matching a previous aws-auth mapRoles username.
eks_admin_name = "eks-admin"

########################################
# Add-ons
#
# Cluster and add-ons are one root module, one state file and one apply. All
# enable_* flags default to false; the values below are the previous
# eks_add-ons/tf-example.tfvars, minus its cluster_name - the add-ons are given
# "<cluster_name>-eks" from the cluster module automatically.
#
# Every add-on needs the Kubernetes API to be reachable from wherever terraform
# runs. With cluster_endpoint_public_access = false above, that means from
# inside the VPC or across a VPN.
########################################

# AWS Load Balancer Controller. Needs the subnet tags that modules/eks applies
# (kubernetes.io/role/elb and .../internal-elb) to place load balancers.
enable_lbc                     = false
lb_namespace                   = "kube-system"
lb_sa_name                     = "lb-controller-tf-example-eks"
lb-controller_chart_repository = "https://aws.github.io/eks-charts"
lb_chart_version               = "1.13.4"

# Amazon EBS CSI Driver.
enable_ebs           = false
ebs_csi_namespace    = "kube-system"
ebs_sa_name          = "ebs-csi-controller-tf-example-eks"
ebs_chart_repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
ebs_chart_version    = "2.48.0"

# Amazon VPC CNI. Leave false on a stock cluster: EKS already runs aws-node and
# owns the "aws-node" service account this would create.
enable_vpc_cni        = false
vpc_cni_namespace     = "kube-system"
vpc_cni_sa_name       = "aws-node"
vpc_cni_chart_version = ""

# Metrics Server. The chart owns its own service account and RBAC, so the names
# below should stay at their defaults.
enable_metrics_server               = false
metrics_server_namespace            = "kube-system"
metrics_server_chart_repository     = "https://kubernetes-sigs.github.io/metrics-server"
metrics_server_chart_name           = "metrics-server"
metrics_server_release_name         = "metrics-server"
metrics_server_service_account_name = "metrics-server"
metrics_server_chart_version        = "3.12.1"

# Cluster Autoscaler. Discovers the node group through the tags EKS puts on its
# ASG, and modules/eks already ignores desired_size so the two do not fight.
enable_cluster_autoscaler           = false
cluster_autoscaler_namespace        = "kube-system"
cluster_autoscaler_release_name     = "cluster-autoscaler"
cluster_autoscaler_chart_repository = "https://kubernetes.github.io/autoscaler"
cluster_autoscaler_chart_name       = "cluster-autoscaler"
cluster_autoscaler_sa_name          = "cluster-autoscaler-tf-example-eks"
cluster_autoscaler_chart_version    = "9.36.0"
