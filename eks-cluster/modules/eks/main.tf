locals {
  # All log types you might want enabled
  eks_cluster_log_types_all = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  # Final list passed to the cluster depending on the var
  eks_cluster_log_types = var.eks_cluster_logging_enabled ? local.eks_cluster_log_types_all : []

  cluster_name = "${var.cluster_name}-eks"
}
