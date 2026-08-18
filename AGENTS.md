# Agents

## Rules

- Do not edit any files without asking first, unless explicitly told to go ahead
- Do not commit changes to git before the user has reviewed them
- Use Conventional Commits for commit messages (e.g. `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`)
- Run `just test` before proposing any changes to verify nothing is broken.
- Run `yamlfmt` on any .yaml files you create or modify to ensure proper formatting.
- Always add a `yaml-language-server` schema comment to custom CRD manifests (e.g. Flux, ESO), but not to native Kubernetes resources (Namespace, Secret, Deployment, etc.), e.g.:
  `# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/<group>/<kind>_<version>.json`

## Structure

```
kubernetes/
  flux/
    ks.yaml                    # Root Flux Kustomization (points to ./kubernetes/apps)
  apps/
    # No kubernetes/apps/kustomization.yaml needed: Flux auto-generates
    # one at the root path and picks up each <namespace>/kustomization.yaml
    # recursively (any subdirectory containing its own kustomization.yaml
    # is included as a resource).
    <namespace>/
      namespace.yaml           # Namespace resource (labels/annotations live here)
      kustomization.yaml       # Kustomize config, includes namespace.yaml + each app's ks.yaml
      <app>/
        ks.yaml                # Flux Kustomization(s) for this app
        app/
          kustomization.yaml   # Kustomize config (sets namespace, lists resources)
          ocirepository.yaml   # OCI chart source
          helmrelease.yaml     # Helm chart deployment
          httproute.yaml       # (optional) Envoy Gateway routing
          externalsecret.yaml  # (optional) Infisical secrets via ESO
        database/              # (optional) database sub-app (e.g. PostgreSQL)
          kustomization.yaml
          ocirepository.yaml
          helmrelease.yaml
          externalsecret.yaml
  components/
    volsync/                   # Kustomize Component for backup/restore
      kustomization.yaml       # kind: Component (not Kustomization)
      ...
  bootstrap/
    helmfile.crds.yaml         # Bootstrap Helmfile for CRDs
    helmfile.apps.yaml         # Bootstrap Helmfile for apps
    secrets.yaml.tpl           # envsubst template for bootstrap secrets
    values.yaml.gotmpl         # Helmfile values template
```
