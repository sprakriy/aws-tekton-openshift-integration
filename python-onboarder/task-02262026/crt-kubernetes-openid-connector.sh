# Get the S3 thumbprint using your working command
S3_THUMBPRINT=$(echo | openssl s_client -servername s3.amazonaws.com -connect s3.amazonaws.com:443 2>/dev/null | openssl x509 -fingerprint -noout -sha1 | sed 's/://g' | awk -F= '{print $2}')

# Create the provider pointing to your BUCKET instead of the internal cluster
aws iam create-open-id-connect-provider \
  --url https://sp-01102026-aws-kub.s3.amazonaws.com \
  --thumbprint-list "$S3_THUMBPRINT" \
  --client-id-list sts.amazonaws.com
