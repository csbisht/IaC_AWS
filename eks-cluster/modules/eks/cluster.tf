resource "aws_eks_cluster" "eks-cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_role.arn
  version  = var.cluster_version

  # enable/disable eks cluster logs
  enabled_cluster_log_types = local.eks_cluster_log_types

  # API_AND_CONFIG_MAP rather than API: any principal already mapped through a
  # pre-existing aws-auth ConfigMap keeps working while access.tf takes over.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.ctr_subnet_ids
    security_group_ids      = [aws_security_group.cluster_additional_security_group.id]
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = true
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = var.kms_key_arn_eks
    }
  }

  tags = {
    Name = local.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}
