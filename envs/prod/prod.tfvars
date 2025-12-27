aws_region         = "us-east-1"
bucket_name        = "vaflt-prod-bucket"
environment        = "prod"
enable_versioning  = true
encryption_algorithm = "AES256"

common_tags = {
  Project     = "VAFLT"
  Environment = "prod"
  Team        = "Platform"
  CostCenter  = "Production"
}

