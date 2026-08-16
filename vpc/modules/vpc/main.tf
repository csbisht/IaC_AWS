locals {
  vpc_name = "${var.name_prefix}-vpc"

  ########################################
  # Subnets
  #
  # var.subnet_groups is a map of groups, each holding a map of availability
  # zone -> CIDR. Everything below flattens that into one map of individual
  # subnets keyed "<group>:<availability zone>", which is the for_each identity
  # of every subnet, association and endpoint ENI placement in this module.
  #
  # Nothing here reads a resource attribute, so the whole layout - which route
  # tables exist, where the NAT gateways go, which subnets carry the endpoints -
  # is known at plan time from the variables alone.
  ########################################

  enabled_groups = { for k, g in var.subnet_groups : k => g if g.enable }

  # Availability zones that actually carry a subnet. An entry whose CIDR was
  # left empty is a placeholder and does not count.
  all_azs = distinct(flatten([
    for gk, g in local.enabled_groups : [for az, cidr in g.cidrs : az if cidr != ""]
  ]))

  # "eu-central-1a" -> "1a", used to keep the Name tags short.
  az_suffix = {
    for az in local.all_azs : az => element(split("-", az), length(split("-", az)) - 1)
  }

  # merge(concat([{}], ...)...) rather than merge(...)... so that a config with
  # no subnet groups at all still produces an empty map instead of an error.
  subnets = merge(concat([{}], [
    for gk, g in local.enabled_groups : {
      for az, cidr in g.cidrs : "${gk}:${az}" => {
        group  = gk
        az     = az
        cidr   = cidr
        public = g.tier == "public"
        name   = "${var.name_prefix}-${g.name != "" ? g.name : gk}-${local.az_suffix[az]}"

        map_public_ip_on_launch = (
          g.map_public_ip_on_launch != null ? g.map_public_ip_on_launch : g.tier == "public"
        )

        # Name last so it wins over anything of that key in the group's tags.
        tags = merge(
          g.tags,
          g.kubernetes_role != "" ? { "kubernetes.io/role/${g.kubernetes_role}" = "1" } : {},
          { for c in g.kubernetes_clusters : "kubernetes.io/cluster/${c}" => "shared" },
          { Name = "${var.name_prefix}-${g.name != "" ? g.name : gk}-${local.az_suffix[az]}" },
        )
      } if cidr != ""
    }
  ])...)

  public_subnets  = { for k, s in local.subnets : k => s if s.public }
  private_subnets = { for k, s in local.subnets : k => s if !s.public }

  public_azs  = sort(distinct([for s in local.public_subnets : s.az]))
  private_azs = sort(distinct([for s in local.private_subnets : s.az]))

  ########################################
  # NAT gateways
  #
  # A NAT gateway lives in a public subnet and is reached from a private one, so
  # both tiers are involved: local.nat_azs decides where the gateways go, and
  # local.nat_az_for_private_az decides which one each private route table uses.
  ########################################

  # One public subnet per AZ to host a gateway - the first by key, so adding a
  # second public group later does not move an existing NAT gateway.
  nat_host_subnet_by_az = {
    for az in local.public_azs :
    az => sort([for k, s in local.public_subnets : k if s.az == az])[0]
  }

  nat_azs = (
    var.nat_gateway_mode == "none" || !var.create_internet_gateway ? [] :
    var.nat_gateway_mode == "single" ? slice(local.public_azs, 0, min(1, length(local.public_azs))) :
    local.public_azs
  )

  # Private AZ -> AZ of the NAT gateway it routes through. Own AZ when there is
  # one there, otherwise the first gateway created; null when there is none at
  # all, which leaves that route table without a default route.
  nat_az_for_private_az = {
    for az in local.private_azs :
    az => (
      length(local.nat_azs) == 0 ? null :
      contains(local.nat_azs, az) ? az : local.nat_azs[0]
    )
  }

  ########################################
  # VPC endpoints
  ########################################

  # Both endpoint variables are maps keyed by service short name, so an entry
  # can be switched off with enable = false and still stay in the file as
  # documentation - the same way a subnet group does. Only the enabled keys ever
  # reach a resource, and the key is the for_each identity, so disabling one
  # service leaves the others untouched.
  gateway_endpoint_services   = sort([for s, e in var.gateway_endpoints : s if e.enable])
  interface_endpoint_services = sort([for s, e in var.interface_endpoints : s if e.enable])

  private_group_keys = sort([for gk, g in local.enabled_groups : gk if g.tier == "private"])

  interface_endpoint_group = (
    var.interface_endpoint_subnet_group != "" ? var.interface_endpoint_subnet_group :
    length(local.private_group_keys) > 0 ? local.private_group_keys[0] : ""
  )

  # One subnet per AZ, guaranteed by the shape of the variable: a group's cidrs
  # is keyed by availability zone, so an AZ cannot appear in it twice. AWS
  # rejects an interface endpoint that names two subnets of the same AZ, which
  # is exactly what a "all private subnets" style lookup would produce here.
  interface_endpoint_subnet_keys = (
    local.interface_endpoint_group == "" ? [] :
    sort([for k, s in local.subnets : k if s.group == local.interface_endpoint_group])
  )

  # Same "@vpc_cidr" placeholder as the ec2 configuration, resolved from the
  # variable rather than from aws_vpc.this, so the security group does not have
  # to wait on the VPC to be planned.
  endpoint_ingress_cidrs = [
    for c in var.vpc_endpoint_ingress_cidrs : c == "@vpc_cidr" ? var.vpc_cidr : c
  ]
}
