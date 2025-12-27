resource "aws_s3_bucket" "test_bucket" {
  bucket = "vaflt-tf-state-test-bucket"
  force_destroy = true
}