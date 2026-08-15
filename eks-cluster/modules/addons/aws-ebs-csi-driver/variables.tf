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

variable "ebs_sa_name" {
  description = "The name of the Kubernetes service account for the EBS CSI Driver"
  type        = string
  default     = "ebs-csi-controller-sa"
  validation {
    condition     = length(regexall("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.ebs_sa_name)) > 0
    error_message = "The service account name must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character."
  }
}

variable "ebs_csi_namespace" {
  description = "The Kubernetes namespace to install AWS ebs csi Controller"
  type        = string
  default     = "kube-system"
}

variable "ebs_chart_version" {
  description = "The version of the AWS EBS CSI Driver Helm chart. Leave empty to use the latest version."
  type        = string
  default     = ""
}

variable "ebs_chart_repository" {
  description = "The Helm chart repository URL for AWS EBS CSI Driver"
  type        = string
  default     = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
}
