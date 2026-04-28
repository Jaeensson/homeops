# Agents

## Rules

- Do not edit any files without asking first, unless explicitly told to go ahead
- Do not commit changes to git before the user has reviewed them
- Always add a `yaml-language-server` schema comment to custom CRD manifests (e.g. Flux, ESO), but not to native Kubernetes resources (Namespace, Secret, Deployment, etc.), e.g.:
  `# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/<group>/<kind>_<version>.json`
