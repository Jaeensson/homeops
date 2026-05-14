---
name: add-app
description: Scaffold a new application into the GitOps repository following the project's established conventions. Use when the user wants to add a new app, service, or component — whether it has a dedicated Helm chart, uses the generic app-template chart for plain Docker images, or consists of raw Kubernetes manifests.
---

# Add App

Scaffold a new application following the project conventions. The steps below are mandatory and must be followed in order. Do not invent structure that is not described here.

## Directory layout

Every application lives under:

```
kubernetes/apps/<namespace>/<app-name>/app/
  kustomization.yaml
  ocirepository.yaml      # Helm-based deployments only
  helmrelease.yaml        # Helm-based deployments only
```

- `<namespace>` is the Kubernetes namespace the app will be deployed into.
- `<app-name>` is a short, lowercase, hyphenated name for the app (e.g. `cert-manager`, `prometheus`).
- Additional component directories (e.g. `store/`, `config/`, `gateway/`) follow the same pattern when the user explicitly asks for extra resources beyond the main app.

## Deployment modes

There are three ways to deploy an app. Choose based on what the upstream project provides:

| Mode | When to use |
|------|-------------|
| **A — Upstream Helm chart** | The project publishes its own Helm chart to an OCI registry |
| **B — app-template** | The project only provides a Docker image (no Helm chart) |
| **C — Raw manifests** | Plain Kubernetes YAML is preferred or the user explicitly asks for it |

When the user does not specify, prefer **A** if an upstream chart exists, otherwise **B**.

---

## Step 1 — Gather information

Before writing any files, ask the user for (or infer from context):

**All modes:**
1. `<namespace>` — target Kubernetes namespace
2. `<app-name>` — name for the app
3. `dependsOn` — whether this Kustomization must wait for another (optional)

**Mode A — Upstream Helm chart:**
4. `<oci-url>` — full OCI chart URL, e.g. `oci://ghcr.io/cert-manager/charts/cert-manager`
5. `<chart-version>` — the chart tag/version to pin, e.g. `v1.17.2`
6. Any Helm `values:` overrides the user wants (optional)

**Mode B — app-template:**
4. `<image-repository>` — container image repository, e.g. `ghcr.io/someone/myapp`
5. `<image-tag>` — image tag to pin, e.g. `1.2.3`
6. Ports, services, persistence, and any other `values:` the user wants (optional)

**Mode C — Raw manifests:**
4. The list of Kubernetes resource files to create

If the namespace does not yet exist as a directory under `kubernetes/apps/`, a new namespace-level `ks.yaml` must also be created (see Step 5b).

---

## Step 2 — Create `kustomization.yaml`

Path: `kubernetes/apps/<namespace>/<app-name>/app/kustomization.yaml`

This is a native Kustomize resource — do NOT add a `yaml-language-server` schema comment.

**Modes A and B:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - ocirepository.yaml
  - helmrelease.yaml
```

**Mode C** — list the raw manifest files instead:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - deployment.yaml
  - service.yaml
```

---

## Step 3 — Create `ocirepository.yaml` (Modes A and B only)

Path: `kubernetes/apps/<namespace>/<app-name>/app/ocirepository.yaml`

This is a Flux CRD — add the `yaml-language-server` schema comment.

**Mode A — Upstream chart:**
```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: <app-name>
spec:
  interval: 1h
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: <chart-version>
  url: <oci-url>
```

**Mode B — app-template** (always pin to the latest stable release; check https://github.com/bjw-s/helm-charts/releases if unsure):
```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: <app-name>
spec:
  interval: 1h
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: <app-template-version>
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

---

## Step 4 — Create `helmrelease.yaml` (Modes A and B only)

Path: `kubernetes/apps/<namespace>/<app-name>/app/helmrelease.yaml`

This is a Flux CRD — add the `yaml-language-server` schema comment.

**Mode A — Upstream chart:**
```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app-name>
spec:
  interval: 1h
  chartRef:
    kind: OCIRepository
    name: <app-name>
  install:
    createNamespace: true
```

**Mode B — app-template** (the `values:` block is the full workload definition):
```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: <app-name>
spec:
  interval: 1h
  chartRef:
    kind: OCIRepository
    name: <app-name>
  install:
    createNamespace: true
  values:
    controllers:
      <app-name>:
        containers:
          app:
            image:
              repository: <image-repository>
              tag: <image-tag>
    service:
      app:
        controller: <app-name>
        ports:
          http:
            port: <port>
```

Expand the `values:` block based on what the user asks for. Common additions:

```yaml
    # Ingress
    ingress:
      app:
        hosts:
          - host: <hostname>
            paths:
              - path: /
                service:
                  identifier: app
                  port: http

    # Persistent storage
    persistence:
      data:
        existingClaim: <pvc-name>
        globalMounts:
          - path: /data

    # Environment variables
    controllers:
      <app-name>:
        containers:
          app:
            env:
              MY_VAR: my-value
```

For the full app-template values reference, see: https://bjw-s.github.io/helm-charts/docs/app-template/

If the user provided additional `values:` overrides for Mode A, add them as a `values:` block after `chartRef`.

---

## Step 5 — Update the namespace-level `ks.yaml`

Path: `kubernetes/apps/<namespace>/ks.yaml`

This file contains one Flux `Kustomization` per component in the namespace. Each entry is a CRD — add the `yaml-language-server` schema comment at the top of the file if it is not already there (one comment for the whole file is sufficient).

### 5a — Namespace `ks.yaml` already exists

Append a new `Kustomization` document to the existing file (YAML multi-document, separated by `---`):

```yaml
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  path: ./kubernetes/apps/<namespace>/<app-name>/app
  prune: true
```

Add `dependsOn` only when the user explicitly asks for ordering:

```yaml
  dependsOn:
    - name: <other-app-name>
```

### 5b — Namespace does not exist yet

Create `kubernetes/apps/<namespace>/ks.yaml` with the single entry above. The `flux/ks.yaml` root Kustomization discovers all namespaces automatically via `path: ./kubernetes/apps` — no changes are needed there.

---

## Step 6 — Verify

After writing all files, confirm the complete list of files created/modified and their paths. Do not run `kubectl apply` or `flux reconcile` unless the user explicitly asks.

---

## Schema comment rules (from AGENTS.md)

- **Add** `yaml-language-server` schema comments to Flux and ESO custom CRD manifests:
  - `OCIRepository` → `https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json`
  - `HelmRelease` → `https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2.json`
  - `Kustomization` (Flux) → `https://kubernetes-schemas.pages.dev/kustomize.toolkit.fluxcd.io/kustomization_v1.json`
- **Do NOT add** schema comments to native Kubernetes resources (`Namespace`, `Secret`, `Deployment`, etc.) or to Kustomize `kustomization.yaml` files.

---

## Examples from this repository

### `external-secrets` (namespace: `external-secrets`) — Mode A

```
kubernetes/apps/external-secrets/
  ks.yaml                          ← Flux Kustomizations for the namespace
  external-secrets/
    app/
      kustomization.yaml
      ocirepository.yaml           ← oci://ghcr.io/external-secrets/charts/external-secrets, tag: 2.4.0
      helmrelease.yaml
    store/
      kustomization.yaml
      clustersecretstore.yaml
```

The `store` Kustomization in `ks.yaml` uses `dependsOn: [external-secrets]` because the CRDs must exist before the store can be applied.

### `network` / `envoy-gateway` (namespace: `network`) — Mode A

```
kubernetes/apps/network/
  ks.yaml
  envoy-gateway/
    app/
      kustomization.yaml
      ocirepository.yaml           ← oci://docker.io/envoyproxy/gateway-helm, tag: 1.7.2
      helmrelease.yaml
    gateway/
      kustomization.yaml
      gatewayclass.yaml
      gateway.yaml
```

### `myapp` (namespace: `default`) — Mode B (app-template)

```
kubernetes/apps/default/
  ks.yaml
  myapp/
    app/
      kustomization.yaml
      ocirepository.yaml           ← oci://ghcr.io/bjw-s/helm-charts/app-template, tag: <version>
      helmrelease.yaml             ← values: defines containers, service, ingress, persistence
```
