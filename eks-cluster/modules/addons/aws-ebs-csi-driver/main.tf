# Cluster identity (name, OIDC provider) is passed in from the root module,
# which creates it. Looking it up here with data "aws_eks_cluster" would fail on
# a fresh apply: the data source is read before the cluster exists.

###############################
# IRSA role for the EBS CSI Driver
###############################
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "AmazonEBSCSIDriverRole-${var.cluster_name}"

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
            "${var.oidc_provider_url}:aud" : "sts.amazonaws.com",
            "${var.oidc_provider_url}:sub" : "system:serviceaccount:${var.ebs_csi_namespace}:${var.ebs_sa_name}"
          }
        }
      }
    ]
  })
}

###############################
# Attach the AWS-managed AmazonEBSCSIDriverPolicy
###############################
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_attach" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

###############################
# Service account, annotated with the IRSA role
###############################
resource "kubernetes_service_account" "ebs_sa" {
  metadata {
    name      = var.ebs_sa_name
    namespace = var.ebs_csi_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_driver_role.arn
    }
  }
}

###############################
# Deploy the Amazon EBS CSI Driver using Helm
###############################
resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = var.ebs_csi_namespace
  repository = var.ebs_chart_repository
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_chart_version

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = "false" # Use our custom service account
    },
    {
      name  = "controller.serviceAccount.name"
      value = var.ebs_sa_name
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver_attach,
    kubernetes_service_account.ebs_sa
  ]
}
