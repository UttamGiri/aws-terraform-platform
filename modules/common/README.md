# Common Module

Reusable Terraform module containing common infrastructure components.

## Purpose

This module provides standardized, reusable infrastructure components that can be used across multiple environments (nonprod, prod) with different configurations.

## What's Included

- S3 bucket with security best practices
- Versioning configuration
- Server-side encryption
- Public access blocking

## Usage

```hcl
module "common" {
  source = "../../modules/common"

  bucket_name       = "my-bucket-name"
  environment       = "prod"
  enable_versioning = true
  encryption_algorithm = "AES256"
  common_tags       = {
    Project = "VAFLT"
    Team    = "Platform"
  }
}
```

## Variables

See `variables.tf` for complete variable documentation.

## Outputs

See `outputs.tf` for available outputs.

