variable "aws_region" {
  description = "Region for the state bucket (must match stack/ root module)"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
  default     = "intentproof-tf-state"
}
