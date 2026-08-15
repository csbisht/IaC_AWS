# Metrics Server talks to the kubelets only, so it needs no IAM role and no
# IRSA wiring - the chart creates its own service account and RBAC.

###############################
# Deploy the Metrics Server using Helm
###############################
resource "helm_release" "metrics_server" {
  name       = var.metrics_server_release_name
  namespace  = var.metrics_server_namespace
  repository = var.metrics_server_chart_repository
  chart      = var.metrics_server_chart_name
  version    = var.metrics_server_chart_version

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    },
    {
      name  = "rbac.create"
      value = "true"
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = var.metrics_server_service_account_name
    },
    {
      name  = "replicas"
      value = "1"
    },
    {
      name  = "metrics.enabled"
      value = "false"
    },
    {
      name  = "serviceMonitor.enabled"
      value = "false"
    }
  ]

  timeout = 300
}
