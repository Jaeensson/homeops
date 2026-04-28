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
