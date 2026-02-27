# pre-task/providers.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No 'backend' block here means it defaults to local state.
  # This is good for the pre-task to avoid the "Chicken and Egg" loop.
}

provider "aws" {
  region = "us-east-1" # Or your preferred region
  # It will use your local AWS CLI credentials (~/.aws/credentials)
    assume_role_with_web_identity {
    role_arn           = "arn:aws:iam::319310747432:role/GitHubAction-AssumeRoleWithAction"
    session_name       = "TektonOIDC"
    # This is the "Force" command
    web_identity_token = file("/var/run/secrets/aws/token")
  }
}