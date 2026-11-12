# The state is kept in S3, one state file per environment. The settings are
# passed at init time, from a file (terraform/example.s3.tfbackend) or from
# the GitHub Actions workflow:
#
#   terraform init -backend-config=dev.s3.tfbackend
#
# terraform validate and terraform test run without it: terraform init -backend=false

terraform {
  backend "s3" {}
}
