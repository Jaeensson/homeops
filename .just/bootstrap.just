set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
bootstrap_dir := kubernetes_dir + '/bootstrap'

default: namespaces secrets apps

# Create namespaces for all apps
namespaces:
    find "{{kubernetes_dir}}/apps" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while IFS= read -r namespace; do \
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -; \
    done

# Create bootstrap secrets from environment variables
secrets:
    envsubst < {{bootstrap_dir}}/secrets.yaml.tpl | kubectl apply -f -

# Bootstrap Flux onto the cluster
apps:
    helmfile -f "{{ kubernetes_dir }}/bootstrap/helmfile.yaml" sync --hide-notes
