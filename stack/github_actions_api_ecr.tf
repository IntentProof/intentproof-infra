# IAM role for IntentProof/intentproof-api GitHub Actions — push release images to ECR on version tags only.
# Trust uses the account GitHub OIDC URL (must exist once per account; see ../bootstrap/github-oidc).

data "aws_caller_identity" "current" {}

locals {
  github_actions_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_api_ecr_trust" {
  count = var.create_github_actions_api_ecr_push_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_actions_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_actions_api_repository}:ref:refs/tags/v*"]
    }
  }
}

data "aws_iam_policy_document" "github_actions_api_ecr_push" {
  count = var.create_github_actions_api_ecr_push_role ? 1 : 0

  statement {
    sid    = "EcrAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushIntentproofApi"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [aws_ecr_repository.api.arn]
  }
}

resource "aws_iam_role" "github_actions_api_ecr_push" {
  count = var.create_github_actions_api_ecr_push_role ? 1 : 0

  name               = var.github_actions_api_ecr_push_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_api_ecr_trust[0].json

  tags = {
    Name        = var.github_actions_api_ecr_push_role_name
    Description = "GitHub Actions OIDC — intentproof-api ECR push (version tags)"
  }
}

resource "aws_iam_role_policy" "github_actions_api_ecr_push" {
  count = var.create_github_actions_api_ecr_push_role ? 1 : 0

  name   = "ecr-push-intentproof-api"
  role   = aws_iam_role.github_actions_api_ecr_push[0].id
  policy = data.aws_iam_policy_document.github_actions_api_ecr_push[0].json
}
