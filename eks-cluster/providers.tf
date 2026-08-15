terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }

    # Used by modules/addons/* to create service accounts, RBAC objects and the
    # Helm releases for the cluster add-ons.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Cluster   = "${var.cluster_name}-eks"
      ManagedBy = "terraform"
    }
  }
}

########################################
# Kubernetes / Helm
########################################

# The credentials below come from the cluster this same root module creates, so
# on a first apply they are unknown at plan time and terraform configures these
# two providers only once module.eks has produced the cluster. That is what lets
# cluster and add-ons live in one state and one apply, with two consequences
# worth knowing:
#
#   * Reaching the Kubernetes API is a hard requirement whenever an add-on is
#     enabled. With cluster_endpoint_public_access = false, terraform has to run
#     from inside the VPC (or over a VPN/Direct Connect that resolves the
#     private endpoint), otherwise the helm/kubernetes resources time out.
#   * Destroying the cluster and the add-ons in a single `terraform destroy`
#     works, but if the cluster is deleted out of band the add-on resources can
#     no longer be refreshed. Remove them from state with `terraform state rm`
#     in that case.
#
# The token is short lived (15 minutes). It is read during apply, immediately
# before the add-ons are created, so it is fresh even when the cluster itself
# took 20 minutes to come up. For very long add-on runs, swap the `token`
# argument for the exec block below, which mints a new token per API call and
# needs the AWS CLI v2 on PATH:
#
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
#   }
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
