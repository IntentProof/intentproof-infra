variable "aws_region" {
  description = "Region for IAM resources (global ARNs; must match account default for console clarity)"
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "Repository name (without org), e.g. intentproof-infra"
  type        = string
}

variable "github_actions_environment" {
  description = "GitHub Environment name used by apply job (must match workflow `environment:`). Included in default OIDC subject allow-list."
  type        = string
  default     = "beta"
}

variable "subject_claims_override" {
  description = "If non-empty, replaces default `repo:...:ref:refs/heads/main`, `pull_request`, and `environment:` patterns. Use to harden trust (exact claims only)."
  type        = list(string)
  default     = []
}

variable "additional_thumbprints" {
  description = "Extra TLS thumbprints for the GitHub OIDC provider (usually empty; AWS may require during certificate rotation)."
  type        = list(string)
  default     = []
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    Set false when https://token.actions.githubusercontent.com is already registered in this AWS account
    (EntityAlreadyExists / 409). Then set existing_github_oidc_provider_arn.
  EOT
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Required when create_github_oidc_provider is false — full ARN from IAM identity providers or `aws iam list-open-id-connect-providers`."
  type        = string
  default     = null

  validation {
    condition     = var.create_github_oidc_provider || (var.existing_github_oidc_provider_arn != null && length(trimspace(var.existing_github_oidc_provider_arn)) > 0)
    error_message = "When create_github_oidc_provider is false, existing_github_oidc_provider_arn must be a non-empty ARN."
  }
}

variable "role_name" {
  description = "IAM role name for applies (merge + manual dispatch) — GitHub secret AWS_TERRAFORM_ROLE_ARN"
  type        = string
  default     = "IntentProofGitHubActionsTerraform"
}

variable "plan_role_name" {
  description = "IAM role for terraform plan on PR and push — GitHub secret AWS_TERRAFORM_PLAN_ROLE_ARN"
  type        = string
  default     = "IntentProofGitHubActionsTerraformPlan"
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket holding remote state (must match stack/main.tf backend bucket and bootstrap/ bucket name)"
  type        = string
  default     = "intentproof-tf-state"
}

variable "plan_managed_policy_arns" {
  description = "Read-only style policies on the plan role (state bucket write is added inline for tflock/state objects)"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

variable "managed_policy_arns" {
  description = <<-EOT
    Managed policies attached to the OIDC role. Default is AdministratorAccess for frictionless ingest stack applies.
    Replace with least-privilege customer-managed policies before external customers / multi-tenant production.
  EOT
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
