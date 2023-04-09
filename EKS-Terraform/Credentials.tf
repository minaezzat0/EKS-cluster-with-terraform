provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["/Users/minaezzat/.aws/credentials"]    // path of your aws_credentials_file
  profile                  = "default"                                // name of profile you want to use
}
