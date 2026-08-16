########################################
# Naming
########################################

variable "name_prefix" {
  type        = string
  description = "Base name for every resource. Each instance is named \"<name_prefix>-<key of var.instances>\"."
}

########################################
# Existing network
#
# Nothing here is created. The VPC and the subnets must already exist; they are
# looked up so that a wrong id fails at plan time rather than half way through
# an apply, and so vpc_cidr can be read back instead of typed twice.
########################################

variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC the instances are launched into."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must be an existing VPC id, e.g. vpc-0a1b2c3d4e5f67890."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the existing VPC, used to expand the \"@vpc_cidr\" placeholder in the security group rules. Leave empty to read it from the VPC itself."
  default     = ""
}

variable "subnet_ids" {
  type        = map(string)
  description = <<-EOT
    Existing subnets, keyed by a short name of your choosing. An instance picks
    one with subnet_key = "<that name>", so subnet ids appear once in the config
    instead of once per instance.

    An instance may also give a literal subnet_id and ignore this map entirely.

    An entry may be left empty (""), so a placeholder for a subnet that does not
    exist yet can stay in the config. Only entries an instance actually points at
    are read, so an empty one costs nothing - but an instance whose subnet_key
    resolves to "" fails at plan time.
  EOT
  default     = {}

  validation {
    condition     = alltrue([for id in values(var.subnet_ids) : id == "" || can(regex("^subnet-[0-9a-f]{8,17}$", id))])
    error_message = "Every entry of subnet_ids must be empty or an existing subnet id, e.g. subnet-0a1b2c3d4e5f67890."
  }
}

########################################
# Security group
########################################

variable "create_security_group" {
  type        = bool
  description = "Create a security group from the rule sets below and attach it to every instance. Set false to rely solely on the additional security groups."
  default     = true
}

variable "sg_ingress_rules" {
  description = "Ingress rules of the security group created for the instances."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description = "SSH from inside the VPC"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["@vpc_cidr"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.sg_ingress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one source: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

variable "sg_egress_rules" {
  description = "Egress rules of the security group created for the instances."

  type = list(object({
    description        = optional(string, "")
    from_port          = number
    to_port            = number
    protocol           = string
    cidr_blocks        = optional(list(string), [])
    ipv6_cidr_blocks   = optional(list(string), [])
    prefix_list_ids    = optional(list(string), [])
    security_group_ids = optional(list(string), [])
    self               = optional(bool, false)
  }))

  default = [
    {
      description = "allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  validation {
    condition = alltrue([
      for r in var.sg_egress_rules :
      r.self || length(concat(r.cidr_blocks, r.ipv6_cidr_blocks, r.prefix_list_ids, r.security_group_ids)) > 0
    ])
    error_message = "Every rule must set at least one destination: cidr_blocks, ipv6_cidr_blocks, prefix_list_ids, security_group_ids or self."
  }
}

########################################
# Existing security groups
########################################

variable "enable_additional_security_groups" {
  type        = bool
  description = "Attach the pre-existing security groups listed in additional_security_groups to every instance. False ignores that list entirely, so it can stay in the tfvars file while switched off."
  default     = false
}

variable "additional_security_groups" {
  description = <<-EOT
    Pre-existing security groups attached to every instance, on top of the one
    this module creates. Only read when enable_additional_security_groups is
    true.

    Give an id, a name, or both:
      id   - used as is, no lookup, no extra IAM permission needed.
      name - the group is looked up by name inside vpc_id. Fails at plan time if
             no group of that name exists, which is the point: a typo does not
             silently launch an instance with one firewall missing.

    When both are set the id wins and the name is documentation.
  EOT

  type = list(object({
    name = optional(string, "")
    id   = optional(string, "")
  }))

  default = []

  validation {
    condition     = alltrue([for sg in var.additional_security_groups : sg.name != "" || sg.id != ""])
    error_message = "Every entry of additional_security_groups must set a name, an id, or both."
  }

  validation {
    condition     = alltrue([for sg in var.additional_security_groups : sg.id == "" || can(regex("^sg-[0-9a-f]{8,17}$", sg.id))])
    error_message = "additional_security_groups ids must look like sg-0a1b2c3d4e5f67890."
  }

  validation {
    condition     = length([for sg in var.additional_security_groups : sg.name if sg.id == ""]) == length(distinct([for sg in var.additional_security_groups : sg.name if sg.id == ""]))
    error_message = "The same security group name is listed twice in additional_security_groups."
  }
}

########################################
# IAM instance profile
########################################

variable "create_instance_profile" {
  type        = bool
  description = "Create an IAM role and instance profile for the instances. Set false to attach an existing profile through instance_profile_name."
  default     = true
}

variable "instance_profile_name" {
  type        = string
  description = "Name of an existing instance profile to attach when create_instance_profile is false. Empty means no profile at all."
  default     = ""
}

variable "iam_role_name" {
  type        = string
  description = "Base name of the created IAM role. The suffix '-EC2InstanceRole' is appended to it."
}

variable "enable_ssm" {
  type        = bool
  description = "Attach AmazonSSMManagedInstanceCore, so instances can be reached with Session Manager instead of SSH or RDP."
  default     = true
}

variable "enable_cloudwatch_agent" {
  type        = bool
  description = "Attach CloudWatchAgentServerPolicy, so the CloudWatch agent can publish metrics and logs."
  default     = false
}

variable "instance_policy_arns" {
  type        = list(string)
  description = "Extra managed policy ARNs attached to the instance role. Anything listed here is reachable from every process on the instance through IMDS - keep it narrow."
  default     = []
}

########################################
# Images
#
# Two operating systems are wired up, selected per instance with os = "linux"
# or os = "windows". An instance can still pin its own ami_id and ignore both.
########################################

variable "ami_ids" {
  description = <<-EOT
    AMI id per operating system, used by instances that do not pin one
    themselves. An empty entry falls back to the matching ami_ssm_parameters
    lookup, i.e. the newest image AWS publishes.
  EOT

  type = object({
    linux   = optional(string, "")
    windows = optional(string, "")
  })

  default = {}

  validation {
    condition = alltrue([
      for id in values(var.ami_ids) : id == "" || can(regex("^ami-[0-9a-f]{8,17}$", id))
    ])
    error_message = "Each entry of ami_ids must be empty or an AMI id, e.g. ami-0a1b2c3d4e5f67890."
  }
}

variable "ami_ssm_parameters" {
  description = <<-EOT
    Public SSM parameters holding the AMI to fall back on per operating system.
    Read only for an operating system that is actually in use and has no id in
    ami_ids and none on the instance.

    The value is resolved on every plan, so a new image published by AWS shows
    up as a replacement of the instance. Pin ami_ids for anything you do not
    want rebuilt by an unrelated apply.
  EOT

  type = object({
    linux   = optional(string, "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64")
    windows = optional(string, "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base")
  })

  default = {}
}

########################################
# Instance defaults
#
# Every value here is the fallback for the matching attribute of var.instances:
# an instance that leaves an attribute null gets the default, so a tfvars file
# only has to spell out what actually differs between instances.
########################################

variable "instance_type" {
  type        = string
  description = "EC2 instance type used by instances that do not set one."
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name attached to instances that do not set one. Leave empty to disable key injection - on Windows that also means no retrievable Administrator password."
  default     = ""
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Give instances a public IP from the subnet. Independent of associate_eip, which allocates a static address instead."
  default     = false
}

variable "monitoring" {
  type        = bool
  description = "Enable EC2 detailed (1-minute) monitoring. Billed per instance."
  default     = false
}

variable "disable_api_termination" {
  type        = bool
  description = "Enable EC2 termination protection. Note that terraform cannot destroy an instance while this is true."
  default     = false
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB. Must be at least as large as the AMI snapshot - 30 for Amazon Linux 2023, 30 for the Windows Server base images."
  default     = 30
}

variable "root_volume_type" {
  type        = string
  description = "Root EBS volume type."
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "standard"], var.root_volume_type)
    error_message = "root_volume_type must be one of gp2, gp3, io1, io2 or standard."
  }
}

variable "root_volume_encrypted" {
  type        = bool
  description = "Encrypt the root volume at launch. Set false only for an AMI that rejects encryption on launch."
  default     = true
}

variable "kms_key_id_ebs" {
  type        = string
  description = "KMS key ARN used to encrypt root and additional EBS volumes. Empty uses the AWS managed aws/ebs key."
  default     = ""
}

variable "metadata_hop_limit" {
  type        = number
  description = <<-EOT
    PUT response hop limit for the instance metadata service.

    1 is the EC2 default and the right value for a plain instance: it stops a
    container or a forwarding proxy on the instance from reaching IMDS. Raise it
    to 2 only when containers on the instance legitimately need the instance
    role.
  EOT
  default     = 1

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 64
    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}

variable "user_data" {
  description = <<-EOT
    First-boot script per operating system, used by instances that do not set
    their own. Passed as plain text; the provider base64 encodes it.

    linux   - a shell script, starting with a #! line.
    windows - PowerShell or cmd wrapped in <powershell>...</powershell> or
              <script>...</script>, which is how EC2Launch decides how to run it.
  EOT

  type = object({
    linux   = optional(string, "")
    windows = optional(string, "")
  })

  default = {}
}

variable "user_data_replace_on_change" {
  type        = bool
  description = <<-EOT
    Control what happens when user_data changes.

      true  - the instance is destroyed and recreated, so the new script runs.
      false - the change is only recorded; user data runs on first boot only,
              so a running instance keeps whatever the old script did.
  EOT
  default     = false
}

########################################
# Instances
########################################

variable "instances" {
  description = <<-EOT
    The instances to create, keyed by a short name that becomes part of every
    resource name and of the Name tag ("<name_prefix>-<key>"). The key is the
    for_each identity: renaming one destroys and recreates that instance, while
    adding or removing an entry leaves the others untouched.

    Each instance must place itself in an existing subnet with either
    subnet_key (a key of var.subnet_ids) or a literal subnet_id. Every other
    attribute falls back to the matching module-level default when left unset.
  EOT

  type = map(object({
    enable     = optional(bool, true)
    count      = optional(number, 1)
    name       = optional(string, "")
    subnet_key = optional(string, "")
    subnet_id  = optional(string, "")

    os                          = optional(string, "linux")
    ami_id                      = optional(string)
    instance_type               = optional(string)
    key_name                    = optional(string)
    private_ip                  = optional(string)
    associate_public_ip_address = optional(bool)
    associate_eip               = optional(bool, false)
    security_group_ids          = optional(list(string), [])
    monitoring                  = optional(bool)
    disable_api_termination     = optional(bool)
    root_volume_size            = optional(number)
    root_volume_type            = optional(string)
    user_data                   = optional(string)
    tags                        = optional(map(string), {})

    # Additional data volumes, created and attached separately from the
    # instance so that resizing or detaching one does not replace the instance.
    ebs_volumes = optional(list(object({
      device_name = string
      size        = number
      type        = optional(string, "gp3")
      iops        = optional(number)
      throughput  = optional(number)
    })), [])
  }))

  validation {
    condition     = alltrue([for k, v in var.instances : v.count >= 0])
    error_message = "count must be 0 or greater."
  }

  validation {
    condition     = length(var.instances) > 0
    error_message = "At least one instance must be defined."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances : (v.subnet_key != "") != (v.subnet_id != "")
    ])
    error_message = "Each instance must set exactly one of subnet_key (a key of subnet_ids) or subnet_id (a literal subnet id)."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances : v.subnet_id == "" || can(regex("^subnet-[0-9a-f]{8,17}$", v.subnet_id))
    ])
    error_message = "A literal subnet_id must look like subnet-0a1b2c3d4e5f67890."
  }

  validation {
    condition     = alltrue([for k, v in var.instances : contains(["linux", "windows"], v.os)])
    error_message = "os must be either \"linux\" or \"windows\"."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances : length(v.ebs_volumes) == length(distinct([for d in v.ebs_volumes : d.device_name]))
    ])
    error_message = "device_name must be unique within the ebs_volumes of a single instance."
  }

  validation {
    condition = alltrue([
      for k, v in var.instances : alltrue([for d in v.ebs_volumes : d.size > 0])
    ])
    error_message = "Every additional EBS volume needs a size greater than 0 GiB."
  }
}
