set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
bootstrap_dir := kubernetes_dir + '/bootstrap'

default: namespaces secrets flux

# Create namespaces for all apps
namespaces:
    find "{{kubernetes_dir}}/apps" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while IFS= read -r namespace; do \
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -; \
    done

# Create bootstrap secrets from environment variables
secrets:
    envsubst < {{bootstrap_dir}}/secrets.yaml.tpl | kubectl apply -f -

# Bootstrap Flux onto the cluster
flux:
    helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
        --version 0.48.0 \
        --namespace flux-system \
        --create-namespace \
        --wait
    helm upgrade --install flux-instance oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance \
        --version 0.48.0 \
        --namespace flux-system \
        --wait \
        --set instance.sync.url="https://github.com/Jaeensson/homeops.git" \
        --set instance.sync.ref="refs/heads/feat/k3s-migration" \
        --set instance.sync.path="kubernetes/apps" \
        --set instance.sync.pullSecret="flux-system"
