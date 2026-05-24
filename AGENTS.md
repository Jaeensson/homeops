# Agents

## Rules

- Do not edit any files without asking first, unless explicitly told to go ahead
- Do not commit changes to git before the user has reviewed them
- Use Conventional Commits for commit messages (e.g. `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`)
- Run `just test` before proposing any changes to verify nothing is broken.
- Run `yamllint` on any .yaml files you create or modify to ensure proper formatting.
- Always add a `yaml-language-server` schema comment to custom CRD manifests (e.g. Flux, ESO), but not to native Kubernetes resources (Namespace, Secret, Deployment, etc.), e.g.:
  `# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/<group>/<kind>_<version>.json`

## Structure

```
kubernetes/
  apps/
    kustomization.yaml         # Root Kustomize config, lists all namespace dirs
    <namespace>/
      namespace.yaml           # Namespace resource (labels/annotations live here)
      kustomization.yaml       # Kustomize config, includes namespace.yaml + each app's ks.yaml
      <app>/
        ks.yaml                # Flux Kustomization(s) for this app
        app/
          kustomization.yaml   # Kustomize config (sets namespace, lists resources)
          ocirepository.yaml   # OCI chart source
          helmrelease.yaml     # Helm chart deployment
  bootstrap/
    secrets.yaml.tpl           # envsubst template for all bootstrap secrets
```
