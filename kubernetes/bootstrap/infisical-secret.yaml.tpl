apiVersion: v1
kind: Secret
metadata:
  name: infisical-credentials
  namespace: external-secrets
type: Opaque
stringData:
  clientId: ${INFISICAL_CLIENT_ID}
  clientSecret: ${INFISICAL_CLIENT_SECRET}
