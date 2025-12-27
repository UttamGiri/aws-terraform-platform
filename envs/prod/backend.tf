terraform {
  backend "s3" {
    bucket         = "vaflt-tf-state-bucket"
    key            = "terraform/prod/platform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vaflt-terraform-locks"
    encrypt        = true
  }
}

