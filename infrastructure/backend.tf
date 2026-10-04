# The bucket must be bootstrapped separately; never create it in this state.
# Local CLI and GitHub Actions must use exactly the same bucket and key.
terraform {
  backend "s3" {
    key          = "gratilo/prd/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
