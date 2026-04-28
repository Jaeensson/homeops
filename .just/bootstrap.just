set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

default: namespaces secrets flux

# Create namespaces for all apps
namespaces:
    for dir in kubernetes/apps/*/; do \
        kubectl create namespace "$(basename "$dir")" --dry-run=client -o yaml | kubectl apply -f -; \
    done

# Create bootstrap secrets from environment variables
secrets:
    envsubst < {{source_directory()}}/../kubernetes/bootstrap/infisical-secret.yaml.tpl | kubectl apply -f -

# Bootstrap Flux onto the cluster
flux:
    helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
        --version 0.48.0 \
        --namespace flux-system \
        --create-namespace \
        --wait
    kubectl create secret generic flux-system \
        -n flux-system \
        --from-literal=username=git \
        --from-literal=password="$GITHUB_TOKEN" \
        --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f {{source_directory()}}/../kubernetes/apps/flux-system/flux-instance/app/fluxinstance.yaml
