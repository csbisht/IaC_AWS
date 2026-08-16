# S3 backend settings, used only when use_s3_backend = true in your *.tfvars.
# Passed to init as -backend-config; these keys fill in the empty
# `backend "s3" {}` body you create in backend_override.tf (README Step 4a).
# Not root module variables - do not pass this file with -var-file.

bucket = "example-tfstate"
key    = "Dev/eu-central-1/vpc/tf-example.tfstate"
region = "eu-central-1"

# State locking. dynamodb_table is deprecated by the S3 backend in favour of
# use_lockfile, which locks with a .tflock object in the same bucket and needs
# no DynamoDB table at all. Keep dynamodb_table only while sharing state with
# older clients that still expect the table.
dynamodb_table = "tf-dev-locks"
# use_lockfile = true

encrypt = true
