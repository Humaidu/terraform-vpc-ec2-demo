terraform {
  backend "s3" {
    bucket = "hash-terraform-state-bucket"
    region = "us-east-1"
    key = "terraform/terraform.tfstate"
  }
}