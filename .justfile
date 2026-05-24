#!/usr/bin/env -S just --justfile

set quiet
set shell := ['bash', '-eu', '-o', 'pipefail', '-c']

[doc('Bootstrap Recipes')]
mod bootstrap '.just/bootstrap.just'

[doc('Kubernetes Recipes')]
mod kube '.just/kube.just'

[doc('Terraform Recipes')]
mod terraform '.just/terraform.just'

[private]
default:
    just --list

deploy: terraform::apply bootstrap::default

test: 
    yamlfmt . -lint && \
    renovate-config-validator .renovaterc.json5 && \
    just kube::test-local