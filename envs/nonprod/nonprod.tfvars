aws_region         = "us-east-1"
bucket_name        = "vaflt-nonprod-bucket"
environment        = "nonprod"
enable_versioning  = true
encryption_algorithm = "AES256"

common_tags = {
  Project     = "VAFLT"
  Environment = "nonprod"
  Team        = "Platform"
}

