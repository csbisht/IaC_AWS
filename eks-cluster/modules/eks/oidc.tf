data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list = ["sts.amazonaws.com"]
  url            = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer

  # The tls provider does not guarantee which entry of the chain is the root,
  # so submit every fingerprint rather than indexing into position 0.
  thumbprint_list = data.tls_certificate.eks.certificates[*].sha1_fingerprint
}
