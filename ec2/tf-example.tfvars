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
# Existing network
#
# All of this must already exist. Nothing here is created: the VPC and every
# subnet listed below are looked up and checked at plan time, so a wrong id
# fails before anything is built.
########################################

vpc_id = "vpc-1234567890"

# CIDR of that VPC, used by the "@vpc_cidr" placeholder in the rules below.
# Leave it empty to have it read back from the VPC instead of typed twice.
vpc_cidr = "172.35.0.0/19"

# The existing subnets, each under a short name of your choosing. Instances
# below point at these with subnet_key = "<name>", so an id appears once here
# rather than once per instance.
#
# The six slots below are the usual three-AZ private/public layout, left empty
# so you only fill in the ones you actually have. An empty entry is ignored -
# only the entries an instance actually points at are looked up in AWS, so the
# rest can stay here as a reminder of what the map is for. Add or rename keys
# freely; the names are yours, nothing in the config depends on them.
#
# Fill in at least the keys the instances at the bottom of this file use
# (private-a and private-c as shipped) - pointing an instance at an empty entry
# stops the plan with a message naming that instance.
subnet_ids = {
  "private-a" = ""
  "private-b" = ""
  "private-c" = ""
  "public-a"  = ""
  "public-b"  = ""
  "public-c"  = ""
}

########################################
# Security group created here
#
# Each entry mirrors an inline aws_security_group rule:
#   description        optional, defaults to ""
#   from_port          required
#   to_port            required
#   protocol           required ("tcp", "udp", "icmp", "-1" for all)
#   cidr_blocks        optional, defaults to []
#   ipv6_cidr_blocks   optional, defaults to []
#   prefix_list_ids    optional, defaults to []
#   security_group_ids optional, defaults to []
#   self               optional, defaults to false
# At least one source/destination must be set per rule.
#
# One placeholder stands in for a value a tfvars file cannot reference:
#   "@vpc_cidr" -> the CIDR of the VPC above
# Anything else is taken literally, so "10.0.0.0/8" or "sg-0abc..." work too.
# For traffic between the instances of this fleet use self = true.
# Set a list to [] to create the security group with no rules in that direction.
########################################

create_security_group = true

sg_ingress_rules = [
  {
    description = "SSH from inside the VPC (Linux)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["@vpc_cidr"]
  },
  {
    description = "RDP from inside the VPC (Windows)"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["@vpc_cidr"]
  },
  {
    description = "HTTPS from inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["@vpc_cidr"]
  },
  {
    description = "all traffic between the instances of this fleet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
]

sg_egress_rules = [
  {
    description = "allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

########################################
# Existing security groups
#
# Switched off by default, so the list below can sit here as documentation
# until you actually want it. Flip enable_additional_security_groups to true
# and every instance gets these on top of the group created above.
#
# Per entry, give an id, a name, or both:
#   id   - used as is, no lookup.
#   name - looked up by name inside vpc_id. A name that does not exist fails
#          the plan, so a typo cannot silently leave a firewall off.
# With both set the id wins and the name is just a note to the reader.
########################################

enable_additional_security_groups = false

additional_security_groups = [
  {
    name = "shared-monitoring-sg"
    id   = "sg-0aaaaaaaaaaaaaaaa"
  },
  {
    # No id: resolved by name inside vpc_id at plan time.
    name = "corp-vpn-access-sg"
  },
]

########################################
# IAM instance profile
########################################

create_instance_profile = true
iam_role_name           = "tf-example"

# Only read when create_instance_profile = false: attach this existing profile
# instead of creating one. Empty means the instances get no profile at all.
instance_profile_name = ""

# Session Manager. With this on you can open a shell (or PowerShell on Windows)
# without a key pair, an inbound rule or a public IP - the instance needs a
# route to the ssm, ssmmessages and ec2messages endpoints.
enable_ssm = true

enable_cloudwatch_agent = false

# Extra managed policies for the instance role. Every process on the instance
# can borrow these through IMDS, so keep the list short and specific - avoid
# the *FullAccess policies here.
instance_policy_arns = [
  # "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
]

########################################
# Images
#
# One AMI per operating system. Each instance picks one with os = "linux" or
# os = "windows"; an instance can still pin an ami_id of its own and ignore
# both entries.
#
# An empty entry means "whatever AWS publishes as newest today", resolved from
# ami_ssm_parameters below. Convenient the first time, but a new AWS release
# then shows up as "forces replacement" on a later plan - fill in a real id for
# anything you do not want rebuilt by an unrelated apply. Look one up with:
#
#   aws ssm get-parameter --region eu-central-1 --query Parameter.Value --output text \
#     --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
########################################

ami_ids = {
  linux   = ""
  windows = ""
}

ami_ssm_parameters = {
  linux   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  windows = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

########################################
# Instance defaults
#
# Anything an entry in `instances` leaves out falls back to these.
########################################

instance_type = "t3.micro"

# Must be an existing EC2 key pair in this region. A name that does not exist
# fails the launch with InvalidKeyPair.NotFound. Leave "" to launch with no key
# and use Session Manager instead - note that a Windows instance launched
# without a key pair has no recoverable Administrator password.
key_name = ""

associate_public_ip_address = false
monitoring                  = false
disable_api_termination     = false

root_volume_size      = 30
root_volume_type      = "gp3"
root_volume_encrypted = true

# Empty uses the AWS managed aws/ebs key. A customer managed key must live in
# the same region and allow this account to use it.
kms_key_id_ebs = ""

# 1 is the EC2 default. Raise to 2 only if containers on the instance need the
# instance role.
metadata_hop_limit = 1

# Default first-boot script per operating system. <<-EOT strips the leading
# indentation. Windows needs the <powershell> wrapper - that is how EC2Launch
# decides how to run the script.
user_data = {
  linux = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y update
  EOT

  windows = <<-EOT
    <powershell>
    Set-TimeZone -Id "UTC"
    </powershell>
  EOT
}

# false: a changed user_data is recorded but not re-run (it only ever runs on
# first boot). true: the instance is replaced so the new script runs.
user_data_replace_on_change = false

########################################
# The instances
#
# Keyed by a short name. The key becomes the Name tag suffix
# ("tf-example-app-01") and the for_each identity - renaming a key destroys and
# recreates that instance, adding or removing one leaves the others alone.
#
# Each entry must say where it goes with exactly one of:
#   subnet_key - a key of the subnet_ids map above (preferred)
#   subnet_id  - a literal subnet id, for a one-off outside that map
# Everything else falls back to the defaults above.
########################################

instances = {
  # Linux instances: set enable to true/false, count for multiple instances, and comma-separated names.
  "linux" = {
    enable        = true
    count         = 2
    name          = "app-01, app-02"
    subnet_key    = "private-a"
    os            = "linux"
    instance_type = "t3.micro"

    ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 100
        type        = "gp3"
        # gp3 defaults to 3000 IOPS / 125 MiB/s when these are left out.
        # iops       = 4000
        # throughput = 250
      }
    ]

    tags = {
      Role = "linux-app"
    }
  }

  # Windows instances: set enable to true/false, count for multiple instances, and name(s).
  "win" = {
    enable        = true
    count         = 1
    name          = "win-01"
    subnet_key    = "private-c"
    os            = "windows"
    instance_type = "t3.medium"

    # Windows data volumes use xvd* device names.
    ebs_volumes = [
      {
        device_name = "xvdf"
        size        = 100
        type        = "gp3"
      }
    ]

    tags = {
      Role = "windows-app"
    }
  }
}
