terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Applied to every taggable resource without repeating them anywhere. Tags set
  # on a resource win over a default_tags entry of the same key, which is how
  # the per-instance Name tag survives.
  default_tags {
    tags = merge(
      {
        Project   = var.name_prefix
        ManagedBy = "terraform"
      },
      var.default_tags,
    )
  }
}
