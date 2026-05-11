output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_terraform_role_arn" {
  description = "GitHub secret AWS_TERRAFORM_ROLE_ARN — applies (workflow_dispatch apply on stack/ and bootstrap when using OIDC)"
  value       = aws_iam_role.github_terraform.arn
}

output "github_terraform_plan_role_arn" {
  description = "GitHub secret AWS_TERRAFORM_PLAN_ROLE_ARN — terraform plan on pull_request and push"
  value       = aws_iam_role.github_terraform_plan.arn
}

output "github_terraform_role_name" {
  value = aws_iam_role.github_terraform.name
}

output "github_terraform_plan_role_name" {
  value = aws_iam_role.github_terraform_plan.name
}
