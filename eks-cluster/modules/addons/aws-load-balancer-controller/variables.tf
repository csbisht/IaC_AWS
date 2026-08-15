variable "cluster_name" {
  description = "Full name of the EKS cluster, as created by modules/eks (i.e. including the '-eks' suffix)."
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

variable "vpc_id" {
  description = "VPC ID of the EKS cluster."
  type        = string
}

variable "lb_sa_name" {
  type        = string
  description = "Service Account name for Load Balancer Controller."
  default     = "aws-load-balancer-controller"
  validation {
    condition     = length(regexall("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.lb_sa_name)) > 0
    error_message = "The service account name must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character."
  }
}

variable "lb_namespace" {
  description = "The Kubernetes namespace to install AWS LoadBalancer controller"
  type        = string
  default     = "kube-system"
}

variable "lb_chart_version" {
  description = "The version of the AWS LoadBalancer controller Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "lb-controller_chart_repository" {
  description = "The Helm chart repository URL for AWS Load Balancer Controller"
  type        = string
  default     = "https://aws.github.io/eks-charts"
}
