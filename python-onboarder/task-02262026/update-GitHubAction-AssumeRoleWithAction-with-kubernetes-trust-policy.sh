aws iam update-assume-role-policy \
  --role-name GitHubAction-AssumeRoleWithAction \
  --policy-document file://trust-policy.json
