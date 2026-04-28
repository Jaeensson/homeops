# Full deployment from scratch
deploy:
    just terraform::apply
    just kubernetes::bootstrap

# Destroy all infrastructure
destroy:
    just terraform::destroy

# Show cluster status
status:
    just kubernetes::status

mod terraform
mod kubernetes
