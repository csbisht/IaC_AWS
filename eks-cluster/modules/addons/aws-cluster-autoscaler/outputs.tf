output "helm_release_status" {
  description = "The status of the Helm release deploying the Cluster Autoscaler"
  value       = helm_release.cluster_autoscaler.status
}

output "role_arn" {
  description = "The ARN of the IAM role for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

output "service_account_name" {
  description = "The name of the Kubernetes service account for Cluster Autoscaler"
  value       = kubernetes_service_account.cluster_autoscaler_sa.metadata[0].name
}
