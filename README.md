# homeops

Personal homelab infrastructure running a single-node k3s cluster on Proxmox, managed with Terraform and GitOps via Flux CD.

## Required local software

| Tool | Purpose |
|---|---|
| [`terraform`](https://developer.hashicorp.com/terraform/install) | Provision the VM and k3s node on Proxmox |
| [`just`](https://github.com/casey/just) | Task runner — entrypoint for deploy, bootstrap and status commands |
| [`kubectl`](https://kubernetes.io/docs/tasks/tools/) | Apply Kubernetes manifests and inspect cluster state |
| [`flux`](https://fluxcd.io/flux/installation/#install-the-flux-cli) | Inspect and manage Flux GitOps state (`flux get ks`, etc.) |
| [`direnv`](https://direnv.net/) | Automatically exports `KUBECONFIG` and other env vars from `.envrc` |
| `ssh` | Used by Terraform to fetch the kubeconfig from the node after provisioning |

## `.envrc.local`

Create `.envrc.local` in the project root (gitignored) and set the following:

```bash
export GITHUB_TOKEN=""              # GitHub PAT — used by just kubernetes::bootstrap for Flux auth
export INFISICAL_CLIENT_ID=""       # Infisical universal auth client ID
export INFISICAL_CLIENT_SECRET=""   # Infisical universal auth client secret
export INFISICAL_PROJECT_ID=""      # Infisical project ID
export INFISICAL_API_URL=""         # Infisical API URL (e.g. https://eu.infisical.com)
```
