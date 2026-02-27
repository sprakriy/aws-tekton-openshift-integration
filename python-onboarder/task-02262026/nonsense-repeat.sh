#946E24DA38A41BD708C5384DE40F235C256C0722
aws iam create-open-id-connect-provider \
  --url https://kubernetes.default.svc.cluster.local \
  --thumbprint-list 946E24DA38A41BD708C5384DE40F235C256C0722 \
  --client-id-list sts.amazonaws.com
