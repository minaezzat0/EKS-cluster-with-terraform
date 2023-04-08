provider "aws" {
  region     = var.aws_region
  shared_credentials_files = ["/Users/minaezzat/.aws/credentials"]
  profile = "default"
}
