apiVersion: v1
kind: Secret
metadata:
  name: infisical-credentials
  namespace: external-secrets
type: Opaque
stringData:
  clientId: ${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}
  clientSecret: ${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}
