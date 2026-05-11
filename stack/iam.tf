data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ── Task execution role (ECS control plane) ───────────────────────────────────
# Needs ECR pull, CloudWatch log write, and Secrets Manager read to inject secrets.

resource "aws_iam_role" "task_execution" {
  name               = "intentproof-ingest-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = { Name = "intentproof-ingest-execution-role" }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "intentproof-secrets-read"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.database_url.arn,
          aws_secretsmanager_secret.api_keys.arn,
        ]
      }
    ]
  })
}

# ── Task role (application runtime) ──────────────────────────────────────────
# Needs: SQS SendMessage (verification queue only), SSM Session Manager (admin path),
# and CloudWatch Logs for execute-command audit.

resource "aws_iam_role" "task" {
  name               = "intentproof-ingest-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = { Name = "intentproof-ingest-task-role" }
}

resource "aws_iam_role_policy" "task_sqs" {
  name = "intentproof-sqs-send"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.verification.arn
      }
    ]
  })
}

# SSM Session Manager — RUNTIME_DECISION.md § 3 admin path
resource "aws_iam_role_policy" "task_ssm" {
  name = "intentproof-ssm-session-manager"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      },
      {
        # ECS ExecuteCommand audit logging to CloudWatch
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      }
    ]
  })
}
