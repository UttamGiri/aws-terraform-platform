# AWS Terraform Platform with GitHub Actions OIDC

This project demonstrates secure AWS infrastructure deployment using Terraform with GitHub Actions and OpenID Connect (OIDC) authentication in an AWS Control Tower multi-account environment.

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

#### AWS Control Tower–Created Roles

Control Tower creates and manages these automatically:

| Role | Purpose |
|------|---------|
| `AWSControlTowerAdmin` | Manages Control Tower & org governance |
| `AWSControlTowerExecution` | Executes changes in member accounts |
| `OrganizationAccountAccessRole` | Legacy admin role for org accounts |

These roles may not explicitly show `organizations:*` permissions, but Control Tower assumes service-linked permissions to manage SCPs. This is by design.

## Understanding IAM/SSO vs SCPs (Mental Model)

### 1️⃣ IAM / SSO Roles are USER-BASED

You assign roles (permission sets) to:
- **Users or groups**
- **For specific accounts**

✅ This is how you give different permissions to developers vs testers

**Example:**
- User A → NonProd-Developer role
- User B → NonProd-Tester role

This is **IAM-level**, not OU-level.

### 2️⃣ SCPs are NOT Role-Based

❌ You do **NOT** assign SCPs to users  
❌ You do **NOT** assign SCPs to roles

✅ SCPs are assigned to:
- **OU** (most common)
- **Account** (rare)

And they apply to **EVERY role and user** inside that account.

### Who Can Change SCPs?

**ONLY** principals in the Management account with:
- `organizations:*` permissions

Control Tower roles have implicit permissions to manage SCPs through service-linked roles.

## SCP Example: Cost Guardrails

### Use Case: Restrict EC2 Instance Types in Sandbox OU

**Goal**: In Sandbox accounts, users can launch EC2 only cheap instance types (e.g., t3.micro, t3.small, t3.medium). Anything bigger should be blocked automatically.

✔ This is **NOT** IAM  
✔ This is **NOT** Control Tower  
✔ This **IS** an SCP applied to the Sandbox OU

### Why SCP Is the Right Tool

- ✅ Applies to everyone
- ✅ Applies to all roles
- ✅ Cannot be bypassed
- ✅ Perfect for cost guardrails

**Budgets tell you after you spend money. SCP stops the spend before it happens.**

### SCP Policy: Allow ONLY Cheap EC2 Instance Types

**Allowed types (example):**
- t3.micro
- t3.small
- t3.medium

Everything else → ❌ denied.

**SCP JSON (Attach to Sandbox OU):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOnlyCheapEC2InstanceTypes",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "ec2:InstanceType": [
            "t3.micro",
            "t3.small",
            "t3.medium"
          ]
        }
      }
    }
  ]
}
```

### What Happens in Practice

| Action | Result |
|--------|--------|
| Launch t3.micro | ✅ Allowed |
| Launch t3.medium | ✅ Allowed |
| Launch m5.large | ❌ Denied |
| Launch c5.xlarge | ❌ Denied |
| Admin tries bigger instance | ❌ Denied |

## End-to-End Login Flow (Federated / Control Tower Model)

### 1️⃣ User Authenticates to the IdP

- User inserts PIV card
- Enters PIN
- Authentication happens entirely at the IdP (PingFederate / Entra ID / Okta)
- MFA + cert validation happens here

👉 **AWS is not involved yet**

### 2️⃣ IdP Federates Identity to AWS

- IdP sends a signed assertion (SAML or OIDC) to AWS
- Assertion says:
  - "This user is authenticated"
  - "They belong to group: Developers"

👉 **Still no IAM user, no role yet**

### 3️⃣ AWS IAM Identity Center Receives the Assertion

AWS:
- Matches the user
- Matches the group
- Looks up permission-set assignments

### 4️⃣ User Selects Account + Role (SSO Portal)

User sees:
```
Non-Prod Account
 └── NonProdDeveloper
```

They click it.

### 5️⃣ AWS Issues Temporary Credentials

- AWS STS creates short-lived credentials
- User is now inside the AWS account
- All actions are logged in CloudTrail

## Setup

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

- `envs/nonprod/` - Non-production environment configuration
- `envs/prod/` - Production environment configuration
- `modules/common/` - Reusable Terraform modules
- `.github/workflows/deploy.yml` - GitHub Actions workflow

## Security

- ✅ No static AWS keys
- ✅ Short-lived OIDC tokens
- ✅ Encrypted S3 state storage
- ✅ State locking with DynamoDB
- ✅ Branch protection recommended
- ✅ SCP-based guardrails for cost control

## References

- [GitHub OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [Reference Repository](https://github.com/amir-cloud-security/terraform-test-oidc)
- [AWS Control Tower Documentation](https://docs.aws.amazon.com/controltower/)
- [AWS Organizations SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
