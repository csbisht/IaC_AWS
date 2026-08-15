module "eks" {
  source = "./modules/eks"

  # Networking
  vpc_id                = var.vpc_id
  vpc_cidr              = var.vpc_cidr
  ctr_subnet_ids        = var.ctr_subnet_ids
  private_ng_subnet_ids = var.private_ng_subnet_ids
  public_subnet_ids     = var.public_subnet_ids

  # Security groups
  cluster_additional_sg_ingress_rules = var.cluster_additional_sg_ingress_rules
  cluster_additional_sg_egress_rules  = var.cluster_additional_sg_egress_rules
  worker_nodes_sg_ingress_rules       = var.worker_nodes_sg_ingress_rules
  worker_nodes_sg_egress_rules        = var.worker_nodes_sg_egress_rules

  # Cluster
  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  iam_role_name                  = var.iam_role_name
  kms_key_arn_eks                = var.kms_key_arn_eks
  kms_key_id_ebs                 = var.kms_key_id_ebs
  eks_cluster_logging_enabled    = var.eks_cluster_logging_enabled
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  # Node group
  deploy_eks_nodegroup        = var.deploy_eks_nodegroup
  node_group_name             = var.node_group_name
  node_group_version          = var.node_group_version
  node_group_desired_capacity = var.node_group_desired_capacity
  node_group_max_capacity     = var.node_group_max_capacity
  node_group_min_capacity     = var.node_group_min_capacity
  instance_type               = var.instance_type
  ami_type                    = var.ami_type
  disk_size                   = var.disk_size
  ssh_key_name                = var.ssh_key_name
  enable_nodegroup_labels     = var.enable_nodegroup_labels
  nodegroup_labels            = var.nodegroup_labels
  enable_nodegroup_taints     = var.enable_nodegroup_taints
  nodegroup_taints            = var.nodegroup_taints

  # Cluster admin access
  enable_eks_admin_access = var.enable_eks_admin_access
  eks_admin_role_arn      = var.eks_admin_role_arn
  eks_admin_name          = var.eks_admin_name
}

########################################
# Add-ons
#
# Each add-on is gated by its own enable_* flag, all of which default to false.
# The modules themselves are unconditional: switching one off removes the module
# instance rather than counting every resource inside it to zero.
#
# Cluster identity is wired straight from module.eks outputs - name, OIDC
# provider ARN and issuer URL - instead of being looked up again with
# data "aws_eks_cluster", which cannot work on a fresh apply. Note that the
# add-ons receive module.eks.cluster_name, i.e. "<cluster_name>-eks", so the
# cluster name only has to be set once in the tfvars.
#
# depends_on = [module.eks] covers the node group as well as the control plane:
# the Helm releases wait for their pods to become ready, which needs schedulable
# nodes. Enabling add-ons with deploy_eks_nodegroup = false and no other compute
# leaves the pods pending and the release times out.
########################################

module "loadbalancer_controller" {
  source = "./modules/addons/aws-load-balancer-controller"
  count  = var.enable_lbc ? 1 : 0

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_provider_url
  vpc_id            = var.vpc_id

  lb_namespace                   = var.lb_namespace
  lb_sa_name                     = var.lb_sa_name
  lb-controller_chart_repository = var.lb-controller_chart_repository
  lb_chart_version               = var.lb_chart_version

  depends_on = [module.eks]
}

module "ebs_csi_driver" {
  source = "./modules/addons/aws-ebs-csi-driver"
  count  = var.enable_ebs ? 1 : 0

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_provider_url

  ebs_csi_namespace    = var.ebs_csi_namespace
  ebs_sa_name          = var.ebs_sa_name
  ebs_chart_repository = var.ebs_chart_repository
  ebs_chart_version    = var.ebs_chart_version

  depends_on = [module.eks]
}

module "vpc_cni" {
  source = "./modules/addons/aws-vpc-cni"
  count  = var.enable_vpc_cni ? 1 : 0

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_provider_url

  vpc_cni_namespace     = var.vpc_cni_namespace
  vpc_cni_sa_name       = var.vpc_cni_sa_name
  vpc_cni_chart_version = var.vpc_cni_chart_version

  depends_on = [module.eks]
}

module "metrics_server" {
  source = "./modules/addons/aws-metrics-server"
  count  = var.enable_metrics_server ? 1 : 0

  metrics_server_namespace            = var.metrics_server_namespace
  metrics_server_chart_repository     = var.metrics_server_chart_repository
  metrics_server_chart_name           = var.metrics_server_chart_name
  metrics_server_chart_version        = var.metrics_server_chart_version
  metrics_server_release_name         = var.metrics_server_release_name
  metrics_server_service_account_name = var.metrics_server_service_account_name

  depends_on = [module.eks]
}

module "cluster_autoscaler" {
  source = "./modules/addons/aws-cluster-autoscaler"
  count  = var.enable_cluster_autoscaler ? 1 : 0

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_provider_url

  cluster_autoscaler_namespace        = var.cluster_autoscaler_namespace
  cluster_autoscaler_release_name     = var.cluster_autoscaler_release_name
  cluster_autoscaler_chart_repository = var.cluster_autoscaler_chart_repository
  cluster_autoscaler_chart_name       = var.cluster_autoscaler_chart_name
  cluster_autoscaler_chart_version    = var.cluster_autoscaler_chart_version
  cluster_autoscaler_sa_name          = var.cluster_autoscaler_sa_name

  depends_on = [module.eks]
}
