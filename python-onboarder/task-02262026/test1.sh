THUMBPRINT=$(kubectl run thumbprint-fetcher -q --image=alpine/openssl --restart=Never --rm -i -- \
  s_client -servername kubernetes.default.svc.cluster.local -connect kubernetes.default.svc.cluster.local:443 </dev/null 2>/dev/null \
  | openssl x509 -fingerprint -noout -sha1 \
  | sed 's/://g' | awk -F= '{print $2}')

# Now check if it actually caught it
echo "REAL THUMBPRINT: $THUMBPRINT"
