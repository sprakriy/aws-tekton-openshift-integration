terraform {
  backend "s3" {
    bucket         = "sp-01102026-aws-kub"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    #dynamodb_table = "terraform-lock" 
  }
}