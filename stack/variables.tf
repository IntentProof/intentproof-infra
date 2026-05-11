variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (beta, staging, prod)"
  type        = string
  default     = "beta"
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "api_keys_json" {
  description = "INTENTPROOF_API_KEYS JSON string, e.g. '{\"key1\":\"tenant-a\",\"key2\":\"tenant-b\"}'"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag in ECR (immutable) — e.g. short git SHA or semver tag v1.2.3 pushed by intentproof-api Release workflow"
  type        = string
}

variable "alarm_email" {
  description = "Email address for the SNS alarm subscription"
  type        = string
  default     = "ops@intentproof.io"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "alb_accept_http" {
  description = "When true (default), ALB listens on :80 with redirect to HTTPS. Set false for HTTPS-only (clients must use 443; update health checks/DNS accordingly)."
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention (days). AWS Free Tier caps this for eligible accounts — use 0 to create without automated backups / PITR (required on many Free Tier accounts). Paid defaults typically use 7."
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35
    error_message = "rds_backup_retention_period must be between 0 and 35."
  }
}

variable "create_github_actions_api_ecr_push_role" {
  description = <<-EOT
    When true, create an IAM role trusted by GitHub OIDC for repository github_actions_api_repository,
    allowing ECR push to the intentproof-api repository on refs/tags/v* only.
    Requires the GitHub Actions OIDC provider URL to exist in the account (bootstrap/github-oidc).
  EOT
  type        = bool
  default     = true
}

variable "github_actions_api_repository" {
  description = "GitHub repository allowed to assume the ECR push role (owner/name), e.g. IntentProof/intentproof-api"
  type        = string
  default     = "IntentProof/intentproof-api"
}

variable "github_actions_api_ecr_push_role_name" {
  description = "IAM role name for intentproof-api GitHub Actions ECR pushes — store ARN as AWS_ECR_PUSH_ROLE_ARN in that repo"
  type        = string
  default     = "IntentProofGitHubActionsApiEcrPush"
}
