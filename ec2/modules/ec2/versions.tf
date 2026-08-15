terraform {
  required_version = ">= 1.6.0"

  # No `provider` block here on purpose. A reusable module declares which
  # providers it needs and inherits the configured instances from its caller;
  # declaring `provider "aws"` inside a module makes the module impossible to
  # use twice (e.g. two fleets in two regions) and blocks its own removal.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }
  }
}
