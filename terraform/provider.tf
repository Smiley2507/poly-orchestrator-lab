# This lab authenticates through a named AWS CLI profile ("sandbox-user"),
# configured once on the operator's machine with `aws configure --profile sandbox-user`.
# Terraform reads credentials from that profile at plan/apply time only - no access
# keys are ever written into this configuration or into state.
provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
