# AWS Terraform Platform with GitHub Actions OIDC

This project demonstrates secure AWS infrastructure deployment using Terraform with GitHub Actions and OpenID Connect (OIDC) authentication.

## Architecture

1. **GitHub Actions** requests a short-lived OIDC token
2. **AWS IAM** trusts the OIDC token (configured as Identity Provider)
3. Workflow **assumes IAM role** (`TerraformCINonProdRole` or `TerraformCIProdRole`) and gets temporary credentials
4. **Terraform** runs and manages infrastructure securely
5. **State** is stored in `vaflt-tf-state-bucket` with locking via `vaflt-terraform-locks` DynamoDB table

## Prerequisites

### Step 1: Enable AWS Control Tower (Manual)

**First, manually enable AWS Control Tower:**

1. Go to AWS Control Tower in the AWS Management Console
2. Enable Control Tower (this is a one-time setup)
3. By default, Control Tower creates two Organizational Units (OUs):
   - **Sandbox OU** - For development and testing workloads
   - **Security OU** - For security and compliance workloads (e.g., Log Archive, Security Tooling)
4. **AWS CloudTrail** and **AWS Config** are automatically applied to all accounts
5. **Always go through Account Factory** to create new accounts (this ensures proper OU assignment and governance)
6. **Note**: You may create additional custom OUs (e.g., NonProd, Prod) as needed for your organization structure

### Step 2: Create Terraform State Infrastructure (Manual)

Create the following resources manually in your Management/Shared Services account:

#### S3 Bucket for State Storage

- **Bucket Name**: `vaflt-tf-state-bucket`
- **Purpose**: Store Terraform state files
- **Configuration**:
  - Enable versioning
  - Enable encryption (SSE-S3 or SSE-KMS)
  - Block all public access
  - Enable bucket versioning

#### DynamoDB Table for State Locking

- **Table Name**: `vaflt-terraform-locks`
- **Purpose**: Enable state locking to prevent concurrent modifications
- **Configuration**:
  - **Partition Key**: `LockID` (String)
  - **Billing Mode**: On-demand or Provisioned (recommended: On-demand)
  - **Region**: Same as S3 bucket (e.g., `us-east-1`)

### Step 3: Create IAM Roles (Manual)

Create the following IAM roles manually in their respective accounts:

#### NonProd Account
- **Role Name**: `TerraformCINonProdRole`
- **Account**: NonProd OU account
- **Purpose**: Allow GitHub Actions to deploy to non-production environment

#### Prod Account
- **Role Name**: `TerraformCIProdRole`
- **Account**: Prod OU account
- **Purpose**: Allow GitHub Actions to deploy to production environment

#### OIDC Trust Policy

Both roles need an OIDC trust policy to allow GitHub Actions to assume them:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**Note**: Replace `<ACCOUNT_ID>`, `<OWNER>`, and `<REPO>` with your actual values.

### Step 4: Create IAM Policy (Manual)

Create the IAM policy `TerraformCIRolePolicy` manually. This policy is used to distinguish between the two roles and provides access to Terraform state resources:

**Policy Name**: `TerraformCIRolePolicy`

**Policy Document**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::vaflt-tf-state-bucket",
        "arn:aws:s3:::vaflt-tf-state-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/vaflt-terraform-locks"
    }
  ]
}
```

**Attach this policy to both roles**:
- `TerraformCINonProdRole`
- `TerraformCIProdRole`

**Note**: The only distinction between the two roles is the Terraform state lock table access. Both roles use the same state bucket and lock table, but operate in different AWS accounts (NonProd vs Prod).

### Step 5: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- **Settings → Secrets and variables → Actions → New repository secret**

#### For NonProd Environment:
- **Name**: `AWS_NON_PROD_ROLE_TO_ASSUME`
- **Value**: `arn:aws:iam::<NONPROD_ACCOUNT_ID>:role/TerraformCINonProdRole`

#### For Prod Environment (if using):
- **Name**: `AWS_PROD_ROLE_TO_ASSUME`
- **Value**: `arn:aws:iam::<PROD_ACCOUNT_ID>:role/TerraformCIProdRole`

**Note**: Replace `<NONPROD_ACCOUNT_ID>` and `<PROD_ACCOUNT_ID>` with your actual AWS account IDs.

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
