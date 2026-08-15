output "ebs_csi_driver_role_arn" {
  description = "The ARN of the IAM role for the Amazon EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

output "ebs_service_account_name" {
  description = "The name of the Kubernetes service account for the Amazon EBS CSI Driver"
  value       = kubernetes_service_account.ebs_sa.metadata[0].name
}

output "ebs_helm_release_status" {
  description = "The status of the Helm release deploying the Amazon EBS CSI Driver"
  value       = helm_release.aws_ebs_csi_driver.status
}
