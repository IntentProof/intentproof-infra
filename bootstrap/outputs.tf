output "state_bucket_name" {
  description = "S3 bucket for Terraform state — must match stack/main.tf backend bucket"
  value       = aws_s3_bucket.tf_state.id
}

output "next_steps" {
  description = "Commands to initialize the ingest stack with remote state"
  value       = <<-EOT
    cd ../stack
    terraform init
    terraform plan
  EOT
}
