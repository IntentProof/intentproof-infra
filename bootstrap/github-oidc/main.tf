terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Partial backend: S3 in steady state; cold bootstrap rewrites to local backend in CI until
  # migrate-state (see `.github/workflows/terraform-bootstrap.yml`).
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "intentproof"
      Component = "github-actions-oidc"
      ManagedBy = "terraform"
    }
  }
}

moved {
  from = aws_iam_openid_connect_provider.github
  to   = aws_iam_openid_connect_provider.github[0]
}

locals {
  default_plan_subjects = [
    "repo:${var.github_org}/${var.github_repo}:pull_request",
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/master",
  ]

  default_apply_subjects = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/master",
    "repo:${var.github_org}/${var.github_repo}:environment:${var.github_actions_environment}",
  ]

  plan_subject_claims  = length(var.subject_claims_override) > 0 ? var.subject_claims_override : local.default_plan_subjects
  apply_subject_claims = length(var.subject_claims_override) > 0 ? var.subject_claims_override : local.default_apply_subjects

  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github_existing[0].arn
}

data "tls_certificate" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = distinct(concat(
    [data.tls_certificate.github_actions[0].certificates[0].sha1_fingerprint],
    var.additional_thumbprints,
  ))
}

data "aws_iam_openid_connect_provider" "github_existing" {
  count = var.create_github_oidc_provider ? 0 : 1
  arn   = var.existing_github_oidc_provider_arn
}

data "aws_iam_policy_document" "github_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_subject_claims
    }
  }
}

data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_subject_claims
    }
  }
}

resource "aws_iam_role" "github_terraform" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_apply_trust.json
}

resource "aws_iam_role_policy_attachment" "github_terraform_managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_terraform.name
  policy_arn = each.value
}

resource "aws_iam_role" "github_terraform_plan" {
  name               = var.plan_role_name
  assume_role_policy = data.aws_iam_policy_document.github_plan_trust.json
}

resource "aws_iam_role_policy_attachment" "github_terraform_plan_readonly" {
  for_each = toset(var.plan_managed_policy_arns)

  role       = aws_iam_role.github_terraform_plan.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "plan_terraform_state_s3" {
  statement {
    sid    = "ListStateBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}"]
  }

  statement {
    sid    = "ReadWriteTerraformStatePrefixes"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.terraform_state_bucket_name}/*"]
  }
}

resource "aws_iam_role_policy" "github_terraform_plan_state" {
  name   = "terraform-plan-state-backend"
  role   = aws_iam_role.github_terraform_plan.name
  policy = data.aws_iam_policy_document.plan_terraform_state_s3.json
}
