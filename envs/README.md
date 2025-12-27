# Environments

Environment-specific Terraform configurations that call the common modules.

## Structure

Each environment has:
- `backend.tf` - **DIFFERENT** state file location
- `main.tf` - Calls the common module
- `variables.tf` - **SAME** variable definitions (symlinked to `../variables.tf`)
- `*.tfvars` - **DIFFERENT** values per environment

**Note**: `variables.tf` is shared across all environments via symlink pointing to `envs/variables.tf`. This ensures variable definitions stay in sync.

## Environments

### nonprod
- State key: `envs/nonprod/terraform.tfstate`
- Configuration: `nonprod.tfvars`

### prod
- State key: `envs/prod/terraform.tfstate`
- Configuration: `prod.tfvars`

## Usage

### Apply Nonprod Environment

```bash
cd envs/nonprod
terraform init
terraform plan -var-file=nonprod.tfvars
terraform apply -var-file=nonprod.tfvars
```

### Apply Prod Environment

```bash
cd envs/prod
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## GitHub Actions

Use the workflow with:
- **stack**: `envs/nonprod` or `envs/prod`
- **environment**: `nonprod` or `prod`

