# Credentials come exclusively from the local shared AWS CLI profile.
# No access keys, secret values or credential files are managed here.
provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Project     = "tipster"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
