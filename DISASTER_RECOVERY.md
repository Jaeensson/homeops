# Disaster Recovery

This document describes how to recover the homelab from a variety of failure
scenarios, how the Terraform + helmfile bootstrap flows work together, and how
to validate that your backups are actually restorable.

---

## Table of Contents

- [Recovery Scenarios](#recovery-scenarios)
  - [Full Cluster Loss (from scratch)](#full-cluster-loss-from-scratch)
  - [Node Rebuild (same Proxmox host, VM lost)](#node-rebuild-same-proxmox-host-vm-lost)
  - [PVC Data Loss (app data corrupted or deleted)](#pvc-data-loss-app-data-corrupted-or-deleted)
- [Understanding the Bootstrap Flow](#understanding-the-bootstrap-flow)
  - [Terraform Layer](#terraform-layer)
  - [Helmfile (CRD + Flux bootstrap) Layer](#helmfile-crd--flux-bootstrap-layer)
  - [Flux GitOps Layer](#flux-gitops-layer)
- [Backups & VolSync](#backups--volsync)
- [Backup Validation & Restore Testing](#backup-validation--restore-testing)
  - [Manual Restore Test Procedure](#manual-restore-test-procedure)
  - [Automated Validation](#automated-validation)
- [Critical Secrets & Their Locations](#critical-secrets--their-locations)

---

## Recovery Scenarios

### Full Cluster Loss (from scratch)

A complete loss means the Proxmox VM is gone, the k3s control-plane data is
gone, and all PVC contents need to be restored from the Restic repository on
the S3 server. This is the most invasive recovery path.

#### Prerequisites

On your workstation (or any machine with network access to Proxmox and the
cluster):

- The checked-out [homeops](https://github.com/Jaeensson/homeops) repository
  at the commit you want to restore
- All tools listed in the [README](./README.md#required-local-software):
  `terraform`, `just`, `kubectl`, `helmfile`, `yq`, `flux`, `direnv`
- `.envrc.local` with the following secrets populated (see README):
  - `GIT_PRIVATE_KEY` / `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`,
    `GITHUB_APP_PRIVATE_KEY` — Flux needs these to authenticate to GitHub
  - `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID`,
    `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET` — External Secrets uses these
    to pull secrets from Infisical
  - `INFISICAL_PROJECT_ID`, `INFISICAL_API_URL`
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — used by Terraform's S3
    backend
- A Proxmox API token with sufficient privileges to create VMs (the same one
  stored in `terraform/terraform.tfvars`)
- SSH key that matches the public key in the Terraform cloud-init user-data
  (the agent-forwarded key or the one pointed at by `~/.ssh/id_ed25519`)

> **Note**: The S3 server (192.168.1.113:9000) and the NFS NAS
> (192.168.1.113) are external infrastructure. If those are also lost you
> need to restore them from their own backups before proceeding.

#### Step-by-step recovery

1. **Source environment variables**

   ```bash
   cd ~/homeops
   direnv allow
   ```

   Verify that `KUBECONFIG`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
   and the Infisical variables are all set.

2. **Provision + bootstrap — `just deploy`**

   ```bash
   just terraform init          # only needed if providers aren't cached yet
   just deploy
   ```

   `just deploy` chains two phases together (defined in the root
   [justfile](./.justfile)):

   1. **Provision the VM and k3s** (`terraform apply`):
      - Creates the Proxmox VM from the Ubuntu cloud image
      - Cloud-init installs and starts k3s
      - Waits for k3s to become healthy
      - Fetches `./kubeconfig.yaml`

   2. **Bootstrap the cluster** (`bootstrap::default` — a four-step
      sequence):
      - `just bootstrap namespaces` — creates all app namespaces
      - `just bootstrap secrets` — injects Infisical and Flux credentials
      - `just bootstrap crds` — installs CRDs (cert-manager,
        external-secrets, envoy-gateway, metallb, volsync, etc.) via
        helmfile
      - `just bootstrap apps` — installs Flux operator + Flux instance
        via helmfile

   You can watch Flux reconcile:

   ```bash
   kubectl get kustomizations -A -w
   ```

   Flux will install every app defined in `kubernetes/apps/`. This includes
   cert-manager, external-secrets, ingress gateways, and all your
   workloads. Because PVCs reference VolSync `ReplicationDestination`
   objects via `dataSourceRef`, the pods will likely remain **pending**
   until PVC data is restored — this is expected.

3. **PVC data restores automatically from VolSync/Restic**

   The VolSync component template
([`kubernetes/components/volsync/`](./kubernetes/components/volsync/))
   is designed to restore data automatically on first reconciliation:

   - The `ReplicationDestination` is created with
     `spec.trigger.manual: restore-once`, which tells VolSync to restore
     the latest Restic snapshot immediately.
   - The `PersistentVolumeClaim` references the `ReplicationDestination`
     via `dataSourceRef`, so it binds to the freshly restored data.

   Once External Secrets has created the `*-volsync-restic` secret (the
   Restic repo credentials pulled from Infisical), Flux will reconcile
   the VolSync resources, and the restore begins without any manual
   intervention.

   You can watch the restore progress:

   ```bash
   kubectl get replicationdestination -A -w
   ```

   After a `ReplicationDestination` shows `Snapshot: <id>` in its status,
   the associated PVC will be populated and the pod will bind and start.

   > **Tip**: Apps with `dependsOn` in their Flux Kustomization (e.g.
   > `vaultwarden` depends on `vaultwarden-database`) may remain unhealthy
   > until their database PVC is restored first. Check the dependency
   > chain in each app's `ks.yaml`.

   > **Note**: The `manual: restore-once` trigger is consumed after the
   > first restore completes. If you need to restore again later (e.g.
   > after data corruption), you can re-trigger it with:
   >
   > ```bash
   > kubectl annotate --overwrite replicationdestination -n <ns> <app>-dst \
   >   volsync.backube/trigger="manual: restore-once"
   > ```

4. **Verify application health**

   ```bash
   just kube status
   kubectl get pods -A
   ```

   Check that:
   - All `Kustomization` resources report `Ready: True`
   - All pods are `Running` or `Completed`
   - External secrets are synced (`kubectl get es -A`)
   - Certificates are issued (`kubectl get certificates -A`)

5. **Verify VolSync backup schedule resumed**

   ```bash
   kubectl get replicationsource -A
   ```

   Each `ReplicationSource` should show a next-sync time. The daily backup
   schedule (`0 0 * * *`) will kick in automatically.

---

### Node Rebuild (same Proxmox host, VM lost)

If the VM is corrupted or the disk is lost but the Proxmox host and external
storage (S3, NFS NAS) are intact:

1. Destroy the old VM in Proxmox (or use `just terraform destroy` if the
   state is still accessible).
2. Follow the steps from [Full Cluster Loss](#full-cluster-loss-from-scratch).
   This is now a single `just deploy` to recreate the VM, bootstrap the
   cluster, and automatically restore PVC data from Restic snapshots.

Since the Restic repository on S3 still has all snapshots, PVC data will
be restored from the existing backups. The Terraform state is stored in
S3 bucket, so it survives the VM loss.

---

### PVC Data Loss (app data corrupted or deleted)

If a single application loses its data but the cluster is otherwise healthy:

1. Scale the affected deployment to 0 replicas (to release the PVC).
2. Delete the PVC:

   ```bash
   kubectl delete pvc -n <namespace> <app>
   ```

3. Annotate the `ReplicationDestination` to trigger a restore (same
   procedure as step 4 above).
4. The Volsync `PVC` template in the component will recreate the PVC bound
   to the restored data.
5. Scale the deployment back up.

You can also use `kubectl cp` or a debug pod to inspect the Restic
repository directly if you only need a single file.

---

## Understanding the Bootstrap Flow

The bootstrap process has three distinct layers that work together to turn a
bare Proxmox VM into a fully running GitOps cluster.

### Terraform Layer

**Entry point**: `just terraform apply`

```
terraform/
├── main.tf              # Calls the k3s_node module
├── providers.tf         # Proxmox provider + S3 backend config
├── variables.tf         # Proxmox endpoint, token, node name
└── modules/k3s_node/
    ├── proxmox.tf       # VM resources, cloud-init user-data, kubeconfig fetch
    ├── providers.tf     # Module-level providers
    ├── variables.tf     # VM specs (CPU, RAM, disk, IP, network)
    └── user-data.yaml.tftpl  # Cloud-init that installs k3s
```

What happens:

1. Terraform downloads the Ubuntu cloud image to Proxmox's storage.
2. It creates a VM with the specified CPU, RAM, and two disks (system +
   storage).
3. Cloud-inits configures networking, mounts the second disk at
   `/var/lib/rancher/k3s/storage`, and installs k3s with:
   - `--tls-san <ip>` for API access via the VM IP
   - `--disable=traefik --disable=servicelb` (ingress and LB are handled by
     Envoy Gateway and MetalLB respectively)
4. After the VM boots, a null_resource waits for k3s to become active, then
   fetches `kubeconfig.yaml` via SSH and writes it to the project root.

**State**: Stored in the `terraform` bucket on S3 (192.168.1.113:9000).
The backend configuration is hard-coded in `providers.tf`. If S3 is
down, Terraform cannot plan or apply. Consider exporting a local state copy
periodically as a safety net.

### Helmfile (CRD + Flux bootstrap) Layer

**Entry point**: `just bootstrap` (or `crds` then `apps`)

```
kubernetes/bootstrap/
├── helmfile.crds.yaml    # CRD-only chart releases
├── helmfile.apps.yaml    # Flux operator + Flux instance releases
├── values.yaml.gotmpl    # Values template for Flux instance HelmRelease
└── secrets.yaml.tpl      # Bootstrap secrets (envsubst template)
```

This layer is split into two phases because CRDs must exist in the cluster
_before_ GitOps reconciles resources that use them.

#### Phase 1 — CRDs (`just bootstrap crds`)

Helmfile renders `helmfile.crds.yaml`, then `yq` filters the output to
extract only `CustomResourceDefinition` objects and applies them with
`--server-side --field-manager bootstrap`.

Charts installed (CRDs only, no actual controllers yet):

| Chart | CRDs |
|---|---|
| cert-manager | Certificate, Issuer, ClusterIssuer |
| external-secrets | ExternalSecret, SecretStore, ClusterSecretStore |
| envoy-gateway | GatewayClass, Gateway, HTTPRoute, etc. |
| metallb | IPAddressPool, L2Advertisement |
| snapshot-controller | VolumeSnapshot, VolumeSnapshotClass, etc. |
| volsync | ReplicationSource, ReplicationDestination |
| grafana-operator | Grafana, GrafanaDashboard, etc. |

#### Phase 2 — Flux bootstrap (`just bootstrap apps`)

Helmfile syncs two releases in order:

1. **flux-operator** — Installs the Flux operator (manages Flux
   installations declaratively via `FluxInstance` CRDs).
2. **flux-instance** — Creates a `FluxInstance` resource that configures
   Flux to sync from the GitHub repository.

The `values.yaml.gotmpl` reads each app's `helmrelease.yaml` from disk and
uses it to dynamically template the Flux instance configuration.

### Flux GitOps Layer

**Entry point**: Flux syncs `kubernetes/flux/ks.yaml`

```
kubernetes/flux/ks.yaml  # Root Kustomization
  └── kubernetes/apps/   # All application namespaces
       ├── <namespace>/
       │   ├── kustomization.yaml
       │   ├── namespace.yaml
       │   ├── <app>/
       │   │   └── ks.yaml        # App-level Flux Kustomization
       │   │       └── app/
       │   │           ├── kustomization.yaml
       │   │           ├── ocirepository.yaml
       │   │           ├── helmrelease.yaml
       │   │           ├── httproute.yaml     (optional)
       │   │           └── externalsecret.yaml (optional)
       │   └── ...
       └── ...
```

The root Kustomization (`kubernetes/flux/ks.yaml`) points at
`./kubernetes/apps` and has a **patch** that injects standard Helm release
defaults (CRD handling, retry strategies) into every child Kustomization.

Each app `ks.yaml` references a local path and may declare `dependsOn` to
control ordering. Flux automatically builds and applies each Kustomization
according to its dependency graph.

**Key point**: Once Flux is bootstrapped, the bootstrap layer is no longer
needed for day-to-day operations — Flux handles all reconciliation. The
bootstrap layer only runs again on full recovery or if you need to wipe and
re-bootstrap the cluster.

---

## Backups

Two complementary backup mechanisms protect application data:

| Layer | Tool | What it backs up | Recovery granularity |
|---|---|---|---|
| PVC-level | VolSync + Restic | Whole persistent volumes (files + databases on disk) | Latest snapshot; whole PVC at a time |
| Database-level | [dbackup](https://github.com/skyfay/dbackup) | Logical dumps of PostgreSQL databases | Point-in-time; individual databases |

### VolSync (PVC snapshots)

All application PVC data is backed up to a S3-compatible object store
using [VolSync](https://volsync.backube/) with the Restic mover.

#### Architecture

```
┌──────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                  │
│                                                      │
│  ┌─────────────────────┐     ┌────────────────────┐  │
│  │ ReplicationSource   │────▶│ Secret (Restic     │  │
│  │ (daily cron)        │     │  repo credentials) │  │
│  └──────────┬──────────┘     └────────────────────┘  │
│             │                         ▲              │
│             │ restic backup           │              │
│             ▼                         │              │
│  ┌─────────────────────┐     ┌────────┴───────┐      │
│  │ ReplicationDest.    │     │ ExternalSecret  │      │
│  │ (manual restore)    │     │ (Infisical)     │      │
│  └─────────────────────┘     └────────────────┘      │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
              ┌─────────────────────┐
              │  S3                 │
              │  192.168.1.113:9000 │
              │  bucket: volsync    │
              └─────────────────────┘
```

Each app that includes the `volsync` component gets a daily Restic snapshot
of its PVC. The backup schedule and retention are defined in
[kubernetes/components/volsync/replicationsource.yaml](./kubernetes/components/volsync/replicationsource.yaml):

- Schedule: `0 0 * * *` (daily at midnight)
- Retention: 7 daily, 4 weekly, 3 monthly
- Prune interval: 7 days

### dbackup (logical database dumps)

[dbackup](https://github.com/skyfay/dbackup) is a web UI that manages
scheduled logical backups of all PostgreSQL databases running inside the
cluster. It connects to each database over the network, performs `pg_dump`,
and stores the resulting dumps on its own PVC (`/data`), which in turn is
backed up daily by VolSync to the same S3 instance
(192.168.1.113:9000) used by all other VolSync Restic repositories. This
gives two layers of protection for database contents:

1. **dbackup's own export schedule** — logical `pg_dump` files on its PVC
2. **VolSync** — Restic snapshots of the entire dbackup PVC on S3

The set of databases and their connection details are configured through
[dbackup's web UI](https://dbackup.egenintres.se), not in Git. This
configuration lives inside the dbackup PVC, so on a full cluster restore the
UI will reflect the last-backed-up configuration once the dbackup PVC is
restored via VolSync.

#### Restoring a single database via dbackup

If you only need to restore one database (rather than a whole PVC), use the
dbackup web UI or its [`/api/restore` endpoint](https://github.com/skyfay/dbackup)
to trigger a restore from a specific dump file.

### Backed-up apps (VolSync)

| App | PVC Capacity | RunAsUser |
|---|---|---|
| vaultwarden | 5Gi | 1000 |
| vaultwarden-database | 10Gi | 999 |
| seerr | 5Gi | 1000 |
| prowlarr | 5Gi | 1000 |
| jellyfin | *varies* | 1000 |
| sabnzbd | *varies* | 1000 |
| immich-database | 10Gi | 999 |
| radarr | *varies* | 1000 |
| sonarr | *varies* | 1000 |
| dbackup | 5Gi | 1001 |
| home-assistant-database | *varies* | 999 |
| mealie | *varies* | 1000 |
| authentik | *varies* | 1000 |

### What is **not** backed up by VolSync

- **Media and downloads** (NFS volumes from the NAS at 192.168.1.113).
  These are `PersistentVolume` resources backed by NFS shares on the
  Synology NAS. They have their own backup strategy outside of this repo.
- **The S3 server itself** — it stores Terraform state and all Restic
  snapshots. Ensure the S3 volume is backed up independently.
- **Flux / Kubernetes state** — etcd snapshots could be added, but the
  current strategy is to treat the cluster as ephemeral and rely on the
  Git repository as the source of truth for all Kubernetes resources.

---

## Backup Validation & Restore Testing

> Restore testing is the only way to know your backups actually work. A
> snapshot that cannot be restored is not a backup — it's a false sense of
> security.

### Manual Restore Test Procedure

This procedure validates that a single app's Restic snapshot can be
restored to a new PVC without affecting the running application.

```bash
# 1. Create a test namespace
kubectl create namespace restore-test

# 2. Copy the VolSync ExternalSecret and ReplicationDestination for the app
#    into the test namespace (adjust APP and values as needed)
cat <<'EOF' | kubectl apply -f -
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: test-<app>-dst
  namespace: restore-test
spec:
  trigger:
    manual: restore-once
  restic:
    repository: <app>-volsync-restic
    destinationPVC: test-<app>
    cleanupCachePVC: true
    cleanupTempPVC: true
    copyMethod: Direct
    accessModes:
      - ReadWriteOnce
    capacity: <VOLSYNC_CAPACITY>
    moverSecurityContext:
      runAsUser: <VOLSYNC_RUNASUSER>
EOF

# 3. Copy the ExternalSecret for the Restic repo into the test namespace
#    (or create a static Secret with the same keys if you have the values)
#    See kubernetes/components/volsync/externalsecret.yaml

# 4. Wait for the restore to complete
kubectl get replicationdestination -n restore-test test-<app>-dst -w

# 5. Create a pod to inspect the restored data
kubectl run -n restore-test inspect --image=ubuntu --rm -it --restart=Never \
  -- bash -c "apt update && apt install -y tree && ls -la /data && tree /data"
#    (mount the PVC at /data by adding a volume to the pod spec, or use
#     a debug sidecar)

# 6. Clean up
kubectl delete namespace restore-test
```

### Automated Validation

Consider adding a Woodpecker pipeline step that periodically runs a restore
test for a subset of apps:

- Provision a temporary PVC from the latest Restic snapshot
- Verify that key files or database dumps exist inside the restored volume
- Report success/failure
- Tear down the test resources

A simple script for this could live in `.woodpecker/validate-restores.yml`.

### Checking snapshot health via CLI

You can also list and verify Restic snapshots directly from a one-shot pod:

```bash
kubectl run -n default restic-check --image=restic/restic --rm -it --restart=Never \
  --env=RESTIC_REPOSITORY="s3:http://192.168.1.113:9000/volsync/<app>" \
  --env=RESTIC_PASSWORD="<password>" \
  --env=AWS_ACCESS_KEY_ID="<key>" \
  --env=AWS_SECRET_ACCESS_KEY="<secret>" \
  -- snapshots
```

Replace `<app>`, `<password>`, `<key>`, `<secret>` with the actual values
from Infisical.

---

## Critical Secrets & Their Locations

| Secret | Where it's stored | Used by |
|---|---|---|
| Proxmox API token | `terraform/terraform.tfvars` (gitignored) | Terraform |
| Infisical credentials | `.envrc.local` → bootstrap Secret `infisical-credentials` → ExternalSecrets | All apps |
| Flux GitHub app key | `.envrc.local` → bootstrap Secret `flux-system` | Flux authentication |
| S3 access keys | `.envrc.local` (Terraform), Infisical `/volsync/` (VolSync) | Terraform backend, Restic repos |
| Restic repo password | Infisical `/volsync/RESTIC_PASSWORD` | VolSync |
| Application secrets (DB passwords, API keys, etc.) | Infisical project `homelab` → ExternalSecrets | Individual apps |

> **Important**: The `.envrc.local` file is the bootstrap seed for all
> secrets. If it is lost, you cannot bootstrap a new cluster without
> recreating its contents from the Infisical dashboard and the GitHub App
> settings page. Keep a secure offline copy of `.envrc.local` (e.g. in a
> password manager or offline vault).

---

## Summary of Key Commands

| Action | Command |
|---|---|
| Provision + bootstrap (full) | `just deploy` |
| Provision VM + k3s only | `just terraform apply` |
| Bootstrap cluster only (after VM is up) | `just bootstrap` |
| Bootstrap individual phases | `just bootstrap namespaces` / `secrets` / `crds` / `apps` |
| Check cluster status | `just kube status` |
| Re-trigger VolSync restore | `kubectl annotate --overwrite replicationdestination ... volsync.backube/trigger="manual: restore-once"` |
| List Restic snapshots | One-shot pod with `restic snapshots` |
| Run pre-commit validation | `just test` |
