variable "cluster_name" {
  description = "Full name of the EKS cluster, as created by modules/eks (i.e. including the '-eks' suffix). Used for ASG auto-discovery."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster is deployed"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, used as the federated principal of the IRSA trust policy."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL with the https:// scheme stripped, used to build the IRSA condition keys."
  type        = string
}

variable "cluster_autoscaler_namespace" {
  description = "The namespace for the Cluster Autoscaler deployment"
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_release_name" {
  description = "The Helm release name for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_repository" {
  description = "The Helm chart repository for Cluster Autoscaler"
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
}

variable "cluster_autoscaler_chart_name" {
  description = "The Helm chart name for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "cluster_autoscaler_chart_version" {
  description = "The version of the Cluster Autoscaler Helm chart to install. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "cluster_autoscaler_sa_name" {
  description = "The name of the service account for Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}
