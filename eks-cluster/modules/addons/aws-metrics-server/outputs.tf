output "helm_release_status" {
  description = "Status of the Helm release for Metrics Server"
  value       = helm_release.metrics_server.status
}

output "service_account_name" {
  description = "Service account used by the Metrics Server"
  value       = var.metrics_server_service_account_name
}
