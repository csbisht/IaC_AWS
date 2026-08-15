resource "aws_eks_node_group" "eks_node_group" {
  count           = var.deploy_eks_nodegroup ? 1 : 0
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_NodeGroupRole.arn
  subnet_ids      = var.private_ng_subnet_ids
  ami_type        = var.ami_type
  instance_types  = var.instance_type
  capacity_type   = "ON_DEMAND"
  version         = var.node_group_version ###node group version

  scaling_config {
    desired_size = var.node_group_desired_capacity
    max_size     = var.node_group_max_capacity
    min_size     = var.node_group_min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_launch_template[0].id
    version = aws_launch_template.eks_launch_template[0].latest_version
  }

  # Toggleable labels
  labels = var.enable_nodegroup_labels ? var.nodegroup_labels : {}

  # Toggleable taints (supports multiple)
  dynamic "taint" {
    for_each = var.enable_nodegroup_taints ? var.nodegroup_taints : []
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  lifecycle {
    # Cluster Autoscaler owns desired_size at runtime; without this every
    # apply would scale the group back to the value in the tfvars file.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_eks_cluster.eks-cluster,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_launch_template.eks_launch_template
  ]
}

resource "aws_launch_template" "eks_launch_template" {
  count = var.deploy_eks_nodegroup ? 1 : 0

  # name_prefix, so an immutable change that forces replacement does not
  # collide with the launch template still held by the live node group.
  name_prefix = "${var.node_group_name}-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_id_ebs
    }
  }

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = false
    delete_on_termination       = true

    # Because this launch template declares its own security groups, EKS will
    # not attach the cluster security group for us - it has to be listed here
    # or nodes cannot reach the control plane.
    security_groups = [
      aws_security_group.worker_nodes_sg.id,
      aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id,
    ]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # Pods reach IMDS through an extra network hop; the EC2 default of 1 would
    # make node-role credentials and IRSA fallback unreachable from containers.
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])
    content {
      resource_type = tag_specifications.value
      tags = {
        Name = var.node_group_name
      }
    }
  }

  # No user_data on purpose. The launch template does not pin an image_id, so
  # EKS generates the correct bootstrap payload for the selected ami_type
  # (nodeadm/NodeConfig on AL2023, bootstrap.sh on AL2). Supplying our own
  # would break node registration.

  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  lifecycle {
    create_before_destroy = true
  }
}
