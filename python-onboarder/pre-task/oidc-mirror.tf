provider "aws" {
  region = "us-east-1" # Or your preferred region
  # It will use your local AWS CLI credentials (~/.aws/credentials)
}

# Use your existing backend bucket name here
locals {
  backend_bucket = "sp-01102026-aws-kub"
}
# 1. Enable ACLs on the bucket (This is the missing link)
resource "aws_s3_bucket_ownership_controls" "oidc_bucket_acl_ownership" {
  bucket = local.backend_bucket
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# 2. Make it public (so AWS can read the keys)
resource "aws_s3_bucket_public_access_block" "oidc_mirror" {
  bucket = local.backend_bucket
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 3. Upload the Discovery Document
resource "aws_s3_object" "discovery" {
  bucket       = local.backend_bucket
  key          = ".well-known/openid-configuration"
  source       = "${path.module}/discovery.json"
  content_type = "application/json"
  #acl          = "public-read"
}

# 4. Upload the Public Keys (Signature Guide)
resource "aws_s3_object" "jwks" {
  bucket       = local.backend_bucket
  key          = "openid/v1/jwks" # Match the path in discovery.json
  source       = "${path.module}/jwks.json"
  content_type = "application/json"
  #acl          = "public-read"
}
# 2. Add this Policy to make ONLY the OIDC folder public
resource "aws_s3_bucket_policy" "oidc_public_read" {
  bucket = local.backend_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicReadForOIDC"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::${local.backend_bucket}/.well-known/*",
          "arn:aws:s3:::${local.backend_bucket}/openid/*"
        ]
      }
    ]
  })
  # Ensure public access block is disabled first
  depends_on = [aws_s3_bucket_public_access_block.oidc_mirror]
}
# 5. Create the Identity Provider in AWS using the S3 URL
resource "aws_iam_openid_connect_provider" "openshift" {
  url             = "https://${local.backend_bucket}.s3.amazonaws.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"] # Standard for S3
}