########################################
# Instance role and profile
#
# Everything attached to this role is reachable from every process on the
# instance through IMDS - there is no per-process scoping the way IRSA gives it
# on EKS. Keep instance_policy_arns as narrow as the workload allows, and
# prefer SSM Session Manager (enable_ssm) over opening SSH.
########################################

locals {
  # one() rather than [0]: both branches of a conditional are evaluated, so
  # indexing a count = 0 resource here would fail exactly when
  # create_instance_profile is false.
  instance_profile_name = (
    var.create_instance_profile ? one(aws_iam_instance_profile.instances[*].name) :
    var.instance_profile_name != "" ? var.instance_profile_name : null
  )
}

resource "aws_iam_role" "instances" {
  count = var.create_instance_profile ? 1 : 0

  name = "${var.iam_role_name}-EC2InstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.iam_role_name}-EC2InstanceRole"
  }
}

resource "aws_iam_instance_profile" "instances" {
  count = var.create_instance_profile ? 1 : 0

  name = "${var.iam_role_name}-EC2InstanceProfile"
  role = aws_iam_role.instances[0].name
}

# Session Manager. Also covers the SSM agent's inventory and patch calls, which
# is what makes an instance manageable without an inbound SSH rule at all.
resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.create_instance_profile && var.enable_ssm ? 1 : 0

  role       = aws_iam_role.instances[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.create_instance_profile && var.enable_cloudwatch_agent ? 1 : 0

  role       = aws_iam_role.instances[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# for_each over the ARNs rather than count over the list, so removing one entry
# does not re-index and churn the attachments after it.
resource "aws_iam_role_policy_attachment" "extra" {
  for_each = var.create_instance_profile ? toset(var.instance_policy_arns) : toset([])

  role       = aws_iam_role.instances[0].name
  policy_arn = each.value
}
