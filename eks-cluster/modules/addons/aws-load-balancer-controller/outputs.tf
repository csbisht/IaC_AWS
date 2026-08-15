output "lb_controller_role_arn" {
  description = "The ARN of the Load Balancer Controller IAM Role"
  value       = aws_iam_role.lb_controller_role.arn
}

output "lb_controller_policy_arn" {
  description = "The ARN of the Load Balancer Controller IAM Policy"
  value       = aws_iam_policy.lb_controller_policy.arn
}

output "custom_service_account_name" {
  description = "The name of the custom Kubernetes service account for the Load Balancer Controller"
  value       = kubernetes_service_account.custom_sa.metadata[0].name
}

output "helm_release_status" {
  description = "The status of the Helm release deploying the Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.status
}
