# Default backend: local state, written to ./terraform.tfstate next to this file.
#
# This is what you get when use_s3_backend = false in your *.tfvars.
#
# Terraform/OpenTofu resolve the backend BEFORE any variables or *.tfvars are
# loaded, so a `backend` block can never read var.use_s3_backend directly -
# variables, locals and expressions are all rejected inside it. Switching to S3
# is therefore a manual step at init time: create a backend_override.tf holding
#
#   terraform {
#     backend "s3" {}
#   }
#
# and run `terraform init -backend-config=tf_config_example.tfvars`. A `backend`
# block in an *_override.tf file replaces the one below entirely, and the empty
# body is filled in from the -backend-config file (see tf_config_example.tfvars
# for the expected keys). README Step 3 walks through it.
#
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
