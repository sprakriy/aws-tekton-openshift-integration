cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::319310747432:oidc-provider/sp-01102026-aws-kub.s3.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "sp-01102026-aws-kub.s3.amazonaws.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

aws iam update-assume-role-policy \
  --role-name GitHubAction-AssumeRoleWithAction \
  --policy-document file://trust-policy.json
