variable "cluster_name" {
  description = "Full name of the EKS cluster, as created by modules/eks (i.e. including the '-eks' suffix)."
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

variable "vpc_cni_sa_name" {
  description = "The name of the Kubernetes service account for the VPC CNI plugin"
  type        = string
  default     = "aws-node"
}

variable "vpc_cni_namespace" {
  description = "The Kubernetes namespace to install AWS VPC CNI Controller"
  type        = string
  default     = "kube-system"
}

variable "vpc_cni_chart_version" {
  description = "The version of the aws-vpc-cni Helm chart to install. Leave empty to use the latest version."
  type        = string
  default     = ""
}
