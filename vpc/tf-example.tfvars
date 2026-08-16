# State backend selector, read at init time - see README Step 3.
#   true  -> remote S3 backend, keys taken from the -backend-config file
#   false -> local state in ./terraform.tfstate
use_s3_backend = false

aws_region  = "eu-central-1"
name_prefix = "tf-example"

# Applied to every resource on top of Project and ManagedBy.
default_tags = {
  Environment = "dev"
  Owner       = "platform-team"
}

########################################
# The VPC itself
#
# The CIDR cannot be changed without replacing the VPC and everything in it, so
# pick it with room to spare. /16 gives 65 536 addresses, which is the usual
# choice when EKS is involved - every pod takes one VPC address there.
#
# Both DNS flags stay on: EKS requires them, and the private DNS names of the
# interface endpoints further down do not work without them.
########################################

vpc_cidr             = "172.32.0.0/16"
enable_dns_support   = true
enable_dns_hostnames = true
instance_tenancy     = "default"

########################################
# Subnets
#
# Three tiers over three availability zones, which is the layout the rest of
# this repository expects:
#
#   pvt - private, for EKS worker nodes and for the ec2 instances
#   ctr - private, for the EKS control plane ENIs
#   pub - public, for load balancers and the NAT gateways
#
# Each group maps availability zone -> CIDR, so an AZ appears at most once per
# group. Drop an AZ by setting its CIDR to "" - the entry stays as a reminder
# and nothing is renumbered. The /20s below carve the /16 into 16 blocks and
# leave the top half free for whatever comes later.
#
# The kubernetes.io tags are what the AWS Load Balancer Controller looks for
# when it decides where to put an internal or an internet-facing load balancer.
# Note that eks-cluster/modules/eks/subnet-tags.tf writes the same two tags onto
# the subnet ids it is given; both write the same value, so they agree - see the
# README section "Handing the subnets to eks-cluster".
########################################

subnet_groups = {
  "pvt" = {
    enable          = true
    tier            = "private"
    kubernetes_role = "internal-elb"

    cidrs = {
      "eu-central-1a" = "172.32.0.0/20"
      "eu-central-1b" = "172.32.16.0/20"
      "eu-central-1c" = "172.32.32.0/20"
    }

    tags = {
      Tier = "application"
    }
  }

  "ctr" = {
    enable          = true
    tier            = "private"
    kubernetes_role = "internal-elb"

    cidrs = {
      "eu-central-1a" = "172.32.48.0/20"
      "eu-central-1b" = "172.32.64.0/20"
      "eu-central-1c" = "172.32.80.0/20"
    }

    tags = {
      Tier = "control-plane"
    }
  }

  "pub" = {
    enable          = true
    tier            = "public"
    kubernetes_role = "elb"

    # Public tiers default to map_public_ip_on_launch = true. Set it to false
    # to keep the route out but stop handing every instance a public address.
    map_public_ip_on_launch = true

    cidrs = {
      "eu-central-1a" = "172.32.96.0/20"
      "eu-central-1b" = "172.32.112.0/20"
      "eu-central-1c" = "172.32.128.0/20"
    }

    tags = {
      Tier = "edge"
    }
  }
}

########################################
# Internet access
#
# nat_gateway_mode is the cost decision in this file. A NAT gateway is billed
# per hour plus per GB, so three of them cost three times as much as one and buy
# you AZ-independent egress:
#
#   "none"       - no NAT at all. Fine for a VPC whose private subnets only talk
#                  to AWS APIs through the endpoints below.
#   "single"     - one gateway, shared by all three AZs. Cheapest; losing that
#                  AZ takes egress down for everything.
#   "one_per_az" - one per AZ, each private route table using its own.
########################################

create_internet_gateway = true
nat_gateway_mode        = "single"

########################################
# VPC endpoints
#
# Gateway endpoints are free and are attached to the private route tables, so
# S3 traffic from the private tiers stops paying NAT data charges. Leave "s3"
# on; add "dynamodb" if anything here uses it.
#
# Interface endpoints are ENIs, billed per hour and per GB. They are how a
# private subnet reaches an AWS API without a NAT gateway. The three ssm ones
# are what Session Manager needs - that is the access path the ec2
# configuration in this repository is set up for.
#
# The ENIs go into one subnet per AZ of interface_endpoint_subnet_group. Empty
# means the first private group in alphabetical order, which with the groups
# above is "ctr" - name "pvt" explicitly to put them with the applications
# instead. The security group created alongside them allows 443 from the
# sources below, without which the endpoint resolves and then times out.
########################################

gateway_endpoints = ["s3"]

interface_endpoints = [
  # "ssm",
  # "ssmmessages",
  # "ec2messages",
  # "secretsmanager",
]

interface_endpoint_subnet_group = ""
interface_endpoint_private_dns  = true

# "@vpc_cidr" expands to vpc_cidr above. Literal CIDRs work as usual.
vpc_endpoint_ingress_cidrs = ["@vpc_cidr"]
