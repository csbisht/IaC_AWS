########################################
# Cluster
########################################

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.eks-cluster.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.eks-cluster.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.eks-cluster.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate for the cluster, for building a kubeconfig."
  value       = aws_eks_cluster.eks-cluster.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group id."
  value       = aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_additional_security_group_id" {
  description = "Additional security group attached to the control plane ENIs."
  value       = aws_security_group.cluster_additional_security_group.id
}

output "worker_nodes_security_group_id" {
  description = "Security group attached to worker node ENIs."
  value       = aws_security_group.worker_nodes_sg.id
}

########################################
# IRSA / OIDC
########################################

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN, used as the federated principal in IRSA trust policies."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "cluster_oidc_provider_url" {
  description = "OIDC issuer URL with the https:// scheme stripped, for IRSA condition keys."
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "test_oidc_role_arn" {
  description = "Sample IRSA role for the default:aws-test service account."
  value       = aws_iam_role.test_oidc.arn
}

########################################
# IAM roles
########################################

output "cluster_iam_role_arn" {
  description = "ARN of the EKS control plane IAM role."
  value       = aws_iam_role.eks_role.arn
}

output "node_group_iam_role_arn" {
  description = "ARN of the worker node group IAM role."
  value       = aws_iam_role.eks_NodeGroupRole.arn
}

########################################
# Node group
########################################

output "node_group_name" {
  description = "Name of the managed node group, or null when deploy_eks_nodegroup is false."
  value       = one(aws_eks_node_group.eks_node_group[*].node_group_name)
}

output "launch_template_id" {
  description = "Id of the worker launch template, or null when deploy_eks_nodegroup is false."
  value       = one(aws_launch_template.eks_launch_template[*].id)
}

########################################
# Cluster admin access
########################################

output "eks_admin_access_entry_arn" {
  description = "ARN of the admin access entry, or null when enable_eks_admin_access is false."
  value       = one(aws_eks_access_entry.admin[*].access_entry_arn)
}

output "eks_admin_user_name" {
  description = "Kubernetes username the admin principal authenticates as, as resolved by EKS. Null when enable_eks_admin_access is false."
  value       = one(aws_eks_access_entry.admin[*].user_name)
}
