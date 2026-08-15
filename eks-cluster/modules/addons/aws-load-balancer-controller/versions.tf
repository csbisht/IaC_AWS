terraform {
  required_version = ">= 1.6.0"

  # Provider instances are inherited from the root module - see the note in
  # modules/eks/versions.tf for why no `provider` block appears here.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
}
