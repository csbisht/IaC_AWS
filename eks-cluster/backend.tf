# Default backend: local state, written to ./terraform.tfstate next to this file.
#
# This is what you get when use_s3_backend = false in your *.tfvars.
#
# Terraform/OpenTofu resolve the backend BEFORE any variables or *.tfvars are
# loaded, so a `backend` block can never read var.use_s3_backend directly -
# variables, locals and expressions are all rejected inside it. The switch is
# therefore applied at init time by tf-init.ps1 / tf-init.sh, which read the
# flag out of your tfvars file and, when it is true, write a
# backend_override.tf containing:
#
#   terraform {
#     backend "s3" {}
#   }
#
# A `backend` block in an *_override.tf file replaces the one below entirely,
# and the empty body is filled in from the -backend-config file the wrapper
# passes (see tf_config_example.tfvars for the expected keys).
#
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
