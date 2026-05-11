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
  description = "Docker image tag (git SHA) to deploy — e.g. 551ffed"
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
