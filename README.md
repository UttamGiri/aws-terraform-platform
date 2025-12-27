# AWS Terraform Platform with GitHub Actions OIDC

This project demonstrates secure AWS infrastructure deployment using Terraform with GitHub Actions and OpenID Connect (OIDC) authentication.

## Architecture

1. **GitHub Actions** requests a short-lived OIDC token
2. **AWS IAM** trusts the OIDC token (configured as Identity Provider)
3. Workflow **assumes IAM role** (`TerraformCIRole`) and gets temporary credentials
4. **Terraform** runs and manages infrastructure securely

## Prerequisites

- AWS Account with:
  - S3 Bucket: `vaflt-tf-state-bucket` (for Terraform state)
  - DynamoDB Table: `vaflt-terraform-locks` (for state locking)
  - IAM Role: `TerraformCIRole` with OIDC trust policy
  - OIDC Identity Provider configured in IAM

## Setup 

### 1. AWS Configuration

- **S3 Backend Bucket**: `vaflt-tf-state-bucket`
- **DynamoDB Lock Table**: `vaflt-terraform-locks`
- **IAM Role**: `TerraformCIRole`

### 2. GitHub Secrets

Add the following secret to your GitHub repository:
- **Settings → Secrets and variables → Actions → New repository secret**
  - Name: `AWS_ROLE_ARN`
  - Value: `arn:aws:iam::<ACCOUNT_ID>:role/TerraformCIRole`

### 3. IAM Policy Requirements

The `TerraformCIRole` should have permissions for:
- S3 operations on `vaflt-tf-state-bucket` (for state storage)
- DynamoDB operations on `vaflt-terraform-locks` (for state locking)
- Any resources you plan to create with Terraform

**Important**: Your IAM policy should include DynamoDB permissions for state locking:

```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:DeleteItem"
  ],
  "Resource": "arn:aws:dynamodb:*:*:table/vaflt-terraform-locks"
}
```

## Usage

1. **Create a Pull Request**: Workflow runs `terraform plan` and comments the plan
2. **Merge to main**: Workflow runs `terraform apply` automatically
3. **Check AWS Console**: Verify resources are created

## Files

- `main.tf` - Main Terraform configuration
- `backend.tf` - S3 backend configuration with DynamoDB locking
- `provider.tf` - AWS provider configuration
- `variables.tf` - Variable definitions
- `versions.tf` - Provider version requirements
- `.github/workflows/deploy.yml` - GitHub Actions workflow

## Security

- ✅ No static AWS keys
- ✅ Short-lived OIDC tokens
- ✅ Encrypted S3 state storage
- ✅ State locking with DynamoDB
- ✅ Branch protection recommended

## References

- [GitHub OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [Reference Repository](https://github.com/amir-cloud-security/terraform-test-oidc)
