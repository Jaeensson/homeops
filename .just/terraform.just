# Initialize Terraform providers and modules
init:
    terraform -chdir="{{justfile_dir()}}/terraform" init

# Show planned infrastructure changes
plan:
    terraform -chdir="{{justfile_dir()}}/terraform" plan

# Apply infrastructure changes
apply:
    terraform -chdir="{{justfile_dir()}}/terraform" apply -auto-approve

# Destroy all infrastructure
destroy:
    terraform -chdir="{{justfile_dir()}}/terraform" destroy

test:
    echo "just_dir() = {{justfile_dir()}}"