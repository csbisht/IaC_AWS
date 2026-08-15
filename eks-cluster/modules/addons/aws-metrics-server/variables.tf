variable "metrics_server_namespace" {
  description = "The Kubernetes namespace to install Metrics Server"
  type        = string
  default     = "kube-system"
}

variable "metrics_server_chart_repository" {
  description = "The Helm chart repository URL for Metrics Server"
  type        = string
  default     = "https://kubernetes-sigs.github.io/metrics-server"
}

variable "metrics_server_chart_name" {
  description = "The name of the Metrics Server Helm chart"
  type        = string
  default     = "metrics-server"
}

variable "metrics_server_chart_version" {
  description = "The version of the Metrics Server Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "metrics_server_release_name" {
  description = "The release name for the Helm deployment"
  type        = string
  default     = "metrics-server"
}

variable "metrics_server_service_account_name" {
  description = "The name of the Kubernetes service account for the Metrics Server"
  type        = string
  default     = "metrics-server"
}
