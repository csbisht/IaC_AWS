# Cluster identity (name, OIDC provider) is passed in from the root module,
# which creates it. Looking it up here with data "aws_eks_cluster" would fail on
# a fresh apply: the data source is read before the cluster exists.
#
# Auto-discovery relies on the k8s.io/cluster-autoscaler/{enabled,<cluster>}
# tags that EKS puts on the ASG behind a managed node group, so nothing extra
# has to be tagged here.

######################################
# IAM policy for Cluster Autoscaler
######################################
resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "EKSClusterAutoscalerPolicy-${var.cluster_name}"
  description = "IAM policy for Cluster Autoscaler on EKS cluster ${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = "*"
      }
    ]
  })
}

######################################
# IRSA role for the Cluster Autoscaler service account
######################################
resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "EKSClusterAutoscalerRole-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com",
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.cluster_autoscaler_namespace}:${var.cluster_autoscaler_sa_name}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = aws_iam_role.cluster_autoscaler_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
}

###############################
# Service account, annotated with the IRSA role
###############################
resource "kubernetes_service_account" "cluster_autoscaler_sa" {
  metadata {
    name      = var.cluster_autoscaler_sa_name
    namespace = var.cluster_autoscaler_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler_role.arn
    }
  }
}

######################################
# ClusterRole for Cluster Autoscaler
######################################
resource "kubernetes_cluster_role" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"
  }

  # Events/endpoints (create/patch needed)
  rule {
    api_groups = [""]
    resources  = ["events", "endpoints"]
    verbs      = ["create", "patch", "watch", "list", "get"]
  }

  # Core read access
  rule {
    api_groups = [""]
    resources = [
      "pods",
      "services",
      "replicationcontrollers",
      "persistentvolumeclaims",
      "persistentvolumes"
    ]
    verbs = ["watch", "list", "get"]
  }

  # Needed for eviction during scale-down
  rule {
    api_groups = [""]
    resources  = ["pods/eviction"]
    verbs      = ["create"]
  }

  # Some versions update pod status
  rule {
    api_groups = [""]
    resources  = ["pods/status"]
    verbs      = ["update"]
  }

  # Nodes: update REQUIRED (for DeletionCandidateTaint)
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["watch", "list", "get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/status"]
    verbs      = ["patch"]
  }

  # Namespaces: list/watch REQUIRED
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["watch", "list", "get"]
  }

  # Status configmap: cluster-autoscaler-status
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["watch", "list", "get", "create", "update", "delete"]
  }

  # Workloads (read)
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets", "statefulsets", "daemonsets", "deployments"]
    verbs      = ["watch", "list", "get"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets", "deployments"]
    verbs      = ["watch", "list", "get"]
  }

  # PDBs (read)
  rule {
    api_groups = ["policy"]
    resources  = ["poddisruptionbudgets"]
    verbs      = ["watch", "list"]
  }

  # Leader election / coordination
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "watch", "list", "create", "update"]
  }

  # Storage objects (read)
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["csinodes", "csidrivers", "csistoragecapacities", "storageclasses"]
    verbs      = ["watch", "list", "get"]
  }

  # Keep if you really need it, but it's unusually broad.
  # If you don't explicitly use autoscaling.k8s.io resources, you can remove this.
  rule {
    api_groups = ["autoscaling.k8s.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

######################################
# ClusterRoleBinding for Cluster Autoscaler
######################################
resource "kubernetes_cluster_role_binding" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster_autoscaler.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cluster_autoscaler_sa.metadata[0].name
    namespace = kubernetes_service_account.cluster_autoscaler_sa.metadata[0].namespace
  }
}

######################################
# Create a dummy secret for the Cluster Autoscaler service account
# This is often needed for older Kubernetes versions or specific setups where
# the default service account secret auto-generation is disabled or not reliable.
######################################
resource "kubernetes_secret" "cluster_autoscaler_secret" {
  metadata {
    name      = "${kubernetes_service_account.cluster_autoscaler_sa.metadata[0].name}-token"
    namespace = var.cluster_autoscaler_namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.cluster_autoscaler_sa.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

######################################
# Deploy the Cluster Autoscaler using Helm
######################################
resource "helm_release" "cluster_autoscaler" {
  name       = var.cluster_autoscaler_release_name
  namespace  = var.cluster_autoscaler_namespace
  repository = var.cluster_autoscaler_chart_repository
  chart      = var.cluster_autoscaler_chart_name
  version    = var.cluster_autoscaler_chart_version

  set = [
    {
      name  = "autoDiscovery.clusterName"
      value = var.cluster_name
    },
    {
      name  = "cloudProvider"
      value = "aws"
    },
    {
      name  = "awsRegion"
      value = var.aws_region
    },
    # RBAC and the service account are managed above, not by the chart.
    {
      name  = "rbac.create"
      value = "false"
    },
    {
      name  = "rbac.serviceAccount.create"
      value = "false"
    },
    {
      name  = "rbac.serviceAccount.name"
      value = kubernetes_service_account.cluster_autoscaler_sa.metadata[0].name
    },
    # Disable Pod Security Policy which can cause conflicts
    {
      name  = "rbac.pspEnabled"
      value = "false"
    }
  ]

  depends_on = [
    kubernetes_service_account.cluster_autoscaler_sa,
    kubernetes_cluster_role.cluster_autoscaler,
    kubernetes_cluster_role_binding.cluster_autoscaler,
    aws_iam_role_policy_attachment.cluster_autoscaler_attach,
    kubernetes_secret.cluster_autoscaler_secret
  ]
}
