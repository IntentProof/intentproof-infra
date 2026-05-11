terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — provision bucket first (see ../bootstrap/README.md).
  # Terraform 1.10+: S3-native locking (Conditional Writes). IAM needs Get/Put/Delete on the *.tflock object path.
  backend "s3" {
    bucket       = "intentproof-tf-state"
    key          = "ingest/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "intentproof"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
