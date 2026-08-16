# Module input interface. The root variables.tf declares the same set with the
# same defaults and forwards them one for one, so a tfvars file written against
# the root works unchanged against this module. Validation lives in both places
# so it also holds for anyone consuming modules/vpc directly.

########################################
# Core / naming
########################################

variable "aws_region" {
  type        = string
  description = "Region the VPC is created in. Used to build the endpoint service names (com.amazonaws.<region>.<service>); it must match the region of the provider passed to this module."
}

variable "name_prefix" {
  type        = string
  description = "Base name for every resource. The VPC itself becomes \"<name_prefix>-vpc\", subnets \"<name_prefix>-<group>-<az suffix>\", and so on."
}

########################################
# VPC
########################################

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR of the VPC. Between /16 and /28; every subnet CIDR below has to sit inside it."

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, e.g. 172.32.0.0/16."
  }
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable the Amazon-provided DNS resolver at the VPC base + 2 address. Required for private DNS names of interface endpoints and for EKS."
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Assign internal DNS hostnames to instances. Required together with enable_dns_support for private DNS on interface endpoints."
  default     = true
}

variable "instance_tenancy" {
  type        = string
  description = "Default tenancy of instances launched into this VPC. \"dedicated\" puts every instance on dedicated hardware and is billed accordingly."
  default     = "default"

  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "instance_tenancy must be either \"default\" or \"dedicated\"."
  }
}

########################################
# Subnets
########################################

variable "subnet_groups" {
  description = <<-EOT
    The subnets to create, grouped by purpose. A group is one tier of the
    network (say "pvt", "ctr", "pub") spread over one or more availability
    zones, and it is the unit everything else keys off: route table association
    follows the group's tier, the Name tag is built from the group name, and the
    outputs are grouped the same way.

    Each group gives its CIDRs as a map of availability zone -> CIDR, so an AZ
    can appear at most once per group. That is what keeps an interface endpoint
    placeable: AWS rejects two subnets of the same AZ on one endpoint.

    A CIDR left empty ("") skips that AZ, so a placeholder for a range you have
    not carved out yet can sit in the file without breaking the plan.

      enable                  - false removes the whole group, leaving it in the
                                file as documentation.
      tier                    - "public"  gets a route to the internet gateway.
                                "private" gets a route to a NAT gateway, if one
                                is created.
      name                    - segment used in the Name tag. Defaults to the
                                map key.
      cidrs                   - availability zone -> IPv4 CIDR inside vpc_cidr.
      map_public_ip_on_launch - defaults to true on a public tier, false on a
                                private one.
      kubernetes_role         - adds "kubernetes.io/role/<value> = 1", which is
                                how the AWS Load Balancer Controller discovers
                                where to put load balancers. Usual values are
                                "elb" for public and "internal-elb" for private.
      kubernetes_clusters     - cluster names to tag with
                                "kubernetes.io/cluster/<name> = shared".
      tags                    - extra tags for every subnet of the group.

    The map key is the for_each identity: renaming a group destroys and
    recreates its subnets, while adding or removing a group leaves the others
    untouched.
  EOT

  type = map(object({
    enable                  = optional(bool, true)
    tier                    = string
    name                    = optional(string, "")
    cidrs                   = map(string)
    map_public_ip_on_launch = optional(bool)
    kubernetes_role         = optional(string, "")
    kubernetes_clusters     = optional(list(string), [])
    tags                    = optional(map(string), {})
  }))

  default = {}

  validation {
    condition     = alltrue([for g in var.subnet_groups : contains(["public", "private"], g.tier)])
    error_message = "Every subnet group must set tier to either \"public\" or \"private\"."
  }

  validation {
    condition = alltrue([
      for g in var.subnet_groups : alltrue([
        for cidr in values(g.cidrs) : cidr == "" || can(cidrhost(cidr, 0))
      ])
    ])
    error_message = "Every entry of a group's cidrs must be empty or a valid IPv4 CIDR, e.g. 172.32.0.0/20."
  }

  # Full containment in vpc_cidr cannot be expressed here - HCL has no address
  # arithmetic - so this only catches the coarse mistake of a subnet wider than
  # the VPC itself. A range of the right size but in the wrong place is rejected
  # by AWS at apply time with InvalidSubnet.Range.
  validation {
    condition = alltrue([
      for g in var.subnet_groups : alltrue([
        for cidr in values(g.cidrs) :
        cidr == "" || tonumber(split("/", cidr)[1]) >= tonumber(split("/", var.vpc_cidr)[1])
      ])
    ])
    error_message = "A subnet CIDR cannot be larger than vpc_cidr - its prefix length must be at least that of the VPC."
  }

  validation {
    condition     = length(flatten([for g in var.subnet_groups : [for cidr in values(g.cidrs) : cidr if cidr != ""]])) == length(distinct(flatten([for g in var.subnet_groups : [for cidr in values(g.cidrs) : cidr if cidr != ""]])))
    error_message = "The same subnet CIDR is used twice across subnet_groups."
  }
}

########################################
# Internet access
########################################

variable "create_internet_gateway" {
  type        = bool
  description = "Create an internet gateway and route the public subnets at it. False leaves the public tier without a default route - and, since a NAT gateway needs the internet gateway, forces nat_gateway_mode = \"none\"."
  default     = true
}

variable "nat_gateway_mode" {
  type        = string
  description = <<-EOT
    How many NAT gateways to create for the private subnets.

      none       - no NAT gateway and no default route on the private tier.
                   Outbound traffic then has to go through VPC endpoints, a
                   transit gateway or an appliance of your own.
      single     - one NAT gateway, in the first public subnet by AZ name. The
                   cheapest option, at the cost of cross-AZ data charges and one
                   AZ whose failure takes egress down for the whole VPC.
      one_per_az - one NAT gateway per AZ that has a public subnet, with each
                   private route table pointing at the one in its own AZ. Every
                   gateway is billed hourly on top of the data it passes.
  EOT
  default     = "single"

  validation {
    condition     = contains(["none", "single", "one_per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of \"none\", \"single\" or \"one_per_az\"."
  }
}

########################################
# VPC endpoints
########################################

variable "gateway_endpoints" {
  type        = list(string)
  description = <<-EOT
    Gateway endpoint services to create, by short name - "s3", "dynamodb".
    Gateway endpoints are free and are wired into the private route tables of
    this VPC, so traffic to those services leaves through the endpoint instead
    of the NAT gateway.

    Public route tables are deliberately left alone: a public subnet already
    reaches those services over the internet gateway at no data charge.
  EOT
  default     = []

  validation {
    condition     = alltrue([for s in var.gateway_endpoints : contains(["s3", "dynamodb"], s)])
    error_message = "AWS only offers gateway endpoints for \"s3\" and \"dynamodb\". Everything else is an interface endpoint."
  }
}

variable "interface_endpoints" {
  type        = list(string)
  description = <<-EOT
    Interface endpoint services to create, by short name - "secretsmanager",
    "ssm", "ssmmessages", "ec2messages", "ecr.api", "ecr.dkr", "sts", "logs".

    Each one puts an ENI in one subnet per AZ of interface_endpoint_subnet_group
    and is billed hourly per ENI plus per GB. They exist so private subnets can
    reach an AWS API without a NAT gateway; ssm + ssmmessages + ec2messages is
    the set that makes Session Manager work on an instance with no egress.
  EOT
  default     = []
}

variable "interface_endpoint_subnet_group" {
  type        = string
  description = "Subnet group the interface endpoint ENIs are placed in, one per AZ of that group. Empty picks the first private group in alphabetical order. A group holds at most one subnet per AZ, which is what AWS requires here."
  default     = ""
}

variable "interface_endpoint_private_dns" {
  type        = bool
  description = "Resolve the service's public hostname (e.g. secretsmanager.eu-central-1.amazonaws.com) to the endpoint ENIs, so existing clients need no change. Needs enable_dns_support and enable_dns_hostnames."
  default     = true
}

variable "vpc_endpoint_ingress_cidrs" {
  type        = list(string)
  description = <<-EOT
    Sources allowed to reach the interface endpoints on TCP 443, through the
    security group created for them. The token "@vpc_cidr" stands for vpc_cidr,
    so the usual "everything in this VPC" does not have to be typed twice;
    anything else is taken literally.

    Only read when interface_endpoints is non-empty.
  EOT
  default     = ["@vpc_cidr"]

  validation {
    condition     = length(var.vpc_endpoint_ingress_cidrs) > 0
    error_message = "vpc_endpoint_ingress_cidrs must list at least one source, otherwise nothing can use the interface endpoints."
  }
}
