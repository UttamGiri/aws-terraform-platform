terraform {
  backend "s3" {
    bucket         = "vaflt-tf-state-bucket"
    key            = "envs/nonprod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vaflt-terraform-locks"
    encrypt        = true
  }
}

