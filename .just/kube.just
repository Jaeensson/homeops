set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

status:
    kubectl get nodes
    kubectl get kustomizations -A
    kubectl get gitrepositories -A