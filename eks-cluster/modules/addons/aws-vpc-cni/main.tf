# Cluster identity (name, OIDC provider) is passed in from the root module,
# which creates it. Looking it up here with data "aws_eks_cluster" would fail on
# a fresh apply: the data source is read before the cluster exists.
#
# Note: EKS ships its own aws-node DaemonSet and "aws-node" service account in
# kube-system. Enabling this module on a cluster that still runs the built-in
# CNI makes terraform try to create a service account that already exists, so
# either delete/import the existing objects first or set vpc_cni_sa_name to a
# name of your own.

###############################
# IRSA role for the Amazon VPC CNI plugin
###############################
resource "aws_iam_role" "vpc_cni_role" {
  name = "AmazonEKSVPCCNIRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : var.oidc_provider_arn
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${var.oidc_provider_url}:sub" : "system:serviceaccount:${var.vpc_cni_namespace}:${var.vpc_cni_sa_name}"
          }
        }
      }
    ]
  })
}

###############################
# Attach the AWS-managed AmazonEKS_CNI_Policy to the role
###############################
resource "aws_iam_role_policy_attachment" "vpc_cni_attach" {
  role       = aws_iam_role.vpc_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

###############################
# Service account, annotated with the IRSA role
###############################
resource "kubernetes_service_account" "vpc_cni_sa" {
  metadata {
    name      = var.vpc_cni_sa_name
    namespace = var.vpc_cni_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vpc_cni_role.arn
    }
  }
}

###############################
# Deploy the Amazon VPC CNI plugin using Helm
###############################
resource "helm_release" "vpc_cni" {
  name       = "aws-vpc-cni"
  namespace  = var.vpc_cni_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-vpc-cni"
  version    = var.vpc_cni_chart_version

  set = [
    {
      name  = "serviceAccount.create"
      value = "false" # Use our custom service account
    },
    {
      name  = "serviceAccount.name"
      value = var.vpc_cni_sa_name
    },
    {
      name  = "awsRegion"
      value = var.aws_region
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.vpc_cni_attach,
    kubernetes_service_account.vpc_cni_sa
  ]
}
