output "vpc_cni_role_arn" {
  description = "The ARN of the IAM role for the Amazon VPC CNI plugin"
  value       = aws_iam_role.vpc_cni_role.arn
}

output "vpc_cni_service_account_name" {
  description = "The name of the Kubernetes service account for the Amazon VPC CNI plugin"
  value       = kubernetes_service_account.vpc_cni_sa.metadata[0].name
}

output "vpc_cni_helm_release_status" {
  description = "The status of the Helm release for the Amazon VPC CNI plugin"
  value       = helm_release.vpc_cni.status
}
