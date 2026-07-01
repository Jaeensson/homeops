set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
bootstrap_dir := kubernetes_dir + '/bootstrap'

default: namespaces secrets crds apps

# Create namespaces for all apps
namespaces:
    find "{{kubernetes_dir}}/apps" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while IFS= read -r namespace; do \
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -; \
    done

# Create bootstrap secrets from environment variables
secrets:
    minijinja-cli "{{bootstrap_dir}}/secrets.yaml.j2" --env -a none | kubectl apply -f -
    
# Create CRDs required by apps
crds:
    helmfile -f "{{ kubernetes_dir }}/bootstrap/helmfile.crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -

# Bootstrap Flux onto the cluster
apps:
    helmfile -f "{{ kubernetes_dir }}/bootstrap/helmfile.apps.yaml" sync --hide-notes
