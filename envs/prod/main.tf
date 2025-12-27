terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "common" {
  source = "../../modules/common"

  bucket_name          = var.bucket_name
  environment          = var.environment
  enable_versioning    = var.enable_versioning
  encryption_algorithm = var.encryption_algorithm
  common_tags          = var.common_tags
}

