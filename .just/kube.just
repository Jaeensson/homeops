set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

status:
    kubectl get nodes
    kubectl get kustomizations -A
    kubectl get gitrepositories -A

apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f /dev/stdin

delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux" "{{ ks }}"