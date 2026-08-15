########################################
# Cluster admin access
#
# Replaces the previous assign_eks-admin_role_to_cluste.tf, which rendered a
# python script with local_file and ran it through a null_resource local-exec
# provisioner to patch the aws-auth ConfigMap and apply a ClusterRole /
# ClusterRoleBinding.
#
# Access entries are the native EKS mechanism for the same outcome and are
# managed entirely through the AWS API, which means:
#   * no kubectl / python3 / aws CLI on the machine running terraform
#   * no network reachability into the VPC at apply time (the old script talked
#     to the Kubernetes API, which is private when
#     cluster_endpoint_public_access = false)
#   * the mapping is real terraform state - drift is detected and revocation is
#     a `terraform destroy` of the entry rather than a manual ConfigMap edit
#   * nothing is written into the module directory at apply time, which the
#     local_file approach did and which breaks when a module is sourced from a
#     read-only location such as .terraform/modules
#
# The whole block is optional. cluster.tf sets
# bootstrap_cluster_creator_admin_permissions = true, so the principal running
# terraform is already a cluster admin and a cluster is usable with
# enable_eks_admin_access = false. Turn it on to add a *second*, named principal
# - note that pointing eks_admin_role_arn at the applying principal itself
# collides with the bootstrap entry and fails with ResourceInUseException.
########################################

resource "aws_eks_access_entry" "admin" {
  count = var.enable_eks_admin_access ? 1 : 0

  cluster_name  = aws_eks_cluster.eks-cluster.name
  principal_arn = var.eks_admin_role_arn
  type          = "STANDARD"

  # Preserves the identity the old aws-auth mapRoles entry projected, so
  # audit-log subjects and any RBAC rules already bound to this username keep
  # matching. Empty means "let EKS derive it from the principal ARN".
  user_name = var.eks_admin_name != "" ? var.eks_admin_name : null

  lifecycle {
    # A precondition rather than a variable validation block: the check spans
    # two variables, which validation blocks only support from terraform 1.9
    # and versions.tf allows >= 1.6. Preconditions are evaluated per instance,
    # so this is silent while the feature is switched off.
    precondition {
      condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.eks_admin_role_arn))
      error_message = "enable_eks_admin_access is true, so eks_admin_role_arn must be an IAM role ARN, e.g. arn:aws:iam::123456789012:role/eks-admin. IAM users and the account root are not valid principals for a STANDARD access entry."
    }
  }
}

resource "aws_eks_access_policy_association" "admin" {
  count = var.enable_eks_admin_access ? 1 : 0

  cluster_name = aws_eks_cluster.eks-cluster.name

  # Referencing the entry rather than the variable keeps the implicit
  # dependency that orders these two, so no depends_on is needed.
  principal_arn = aws_eks_access_entry.admin[0].principal_arn

  # AWS-managed equivalent of the cluster-wide '*' ClusterRole the old
  # eks-admin-clusterRole.yaml.tmpl created.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
