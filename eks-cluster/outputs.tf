output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate for the cluster, for building a kubeconfig."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN, used as the federated principal in IRSA trust policies."
  value       = module.eks.cluster_oidc_provider_arn
}

output "cluster_oidc_provider_url" {
  description = "OIDC issuer URL with the https:// scheme stripped, for IRSA condition keys."
  value       = module.eks.cluster_oidc_provider_url
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group id."
  value       = module.eks.cluster_security_group_id
}

output "worker_nodes_security_group_id" {
  description = "Security group attached to worker node ENIs."
  value       = module.eks.worker_nodes_security_group_id
}

output "node_group_iam_role_arn" {
  description = "ARN of the worker node group IAM role."
  value       = module.eks.node_group_iam_role_arn
}

output "test_oidc_role_arn" {
  description = "Sample IRSA role for the default:aws-test service account."
  value       = module.eks.test_oidc_role_arn
}

output "eks_admin_access_entry_arn" {
  description = "ARN of the admin access entry, or null when enable_eks_admin_access is false."
  value       = module.eks.eks_admin_access_entry_arn
}

output "eks_admin_user_name" {
  description = "Kubernetes username the admin principal authenticates as. Null when enable_eks_admin_access is false."
  value       = module.eks.eks_admin_user_name
}

########################################
# Add-ons
#
# one() unwraps the count-based module lists: every add-on output is null while
# its enable_* flag is false, rather than the empty string the standalone
# eks_add-ons root used to return.
########################################

# --- AWS Load Balancer Controller ---

output "lb_controller_role_arn" {
  description = "IAM role assumed by the Load Balancer Controller service account."
  value       = one(module.loadbalancer_controller[*].lb_controller_role_arn)
}

output "lb_controller_policy_arn" {
  description = "IAM policy attached to the Load Balancer Controller role."
  value       = one(module.loadbalancer_controller[*].lb_controller_policy_arn)
}

output "lb_controller_service_account_name" {
  description = "Service account the Load Balancer Controller runs as."
  value       = one(module.loadbalancer_controller[*].custom_service_account_name)
}

output "lb_controller_helm_release_status" {
  description = "Status of the Load Balancer Controller Helm release."
  value       = one(module.loadbalancer_controller[*].helm_release_status)
}

# --- Amazon EBS CSI Driver ---

output "ebs_csi_driver_role_arn" {
  description = "IAM role assumed by the EBS CSI Driver service account."
  value       = one(module.ebs_csi_driver[*].ebs_csi_driver_role_arn)
}

output "ebs_service_account_name" {
  description = "Service account the EBS CSI Driver controller runs as."
  value       = one(module.ebs_csi_driver[*].ebs_service_account_name)
}

output "ebs_helm_release_status" {
  description = "Status of the EBS CSI Driver Helm release."
  value       = one(module.ebs_csi_driver[*].ebs_helm_release_status)
}

# --- Amazon VPC CNI ---

output "vpc_cni_role_arn" {
  description = "IAM role assumed by the VPC CNI service account."
  value       = one(module.vpc_cni[*].vpc_cni_role_arn)
}

output "vpc_cni_service_account_name" {
  description = "Service account the VPC CNI plugin runs as."
  value       = one(module.vpc_cni[*].vpc_cni_service_account_name)
}

output "vpc_cni_helm_release_status" {
  description = "Status of the VPC CNI Helm release."
  value       = one(module.vpc_cni[*].vpc_cni_helm_release_status)
}

# --- Metrics Server ---

output "metrics_server_helm_release_status" {
  description = "Status of the Metrics Server Helm release."
  value       = one(module.metrics_server[*].helm_release_status)
}

output "metrics_server_service_account_name" {
  description = "Service account the Metrics Server runs as."
  value       = one(module.metrics_server[*].service_account_name)
}

# --- Cluster Autoscaler ---

output "cluster_autoscaler_role_arn" {
  description = "IAM role assumed by the Cluster Autoscaler service account."
  value       = one(module.cluster_autoscaler[*].role_arn)
}

output "cluster_autoscaler_service_account_name" {
  description = "Service account the Cluster Autoscaler runs as."
  value       = one(module.cluster_autoscaler[*].service_account_name)
}

output "cluster_autoscaler_helm_release_status" {
  description = "Status of the Cluster Autoscaler Helm release."
  value       = one(module.cluster_autoscaler[*].helm_release_status)
}
