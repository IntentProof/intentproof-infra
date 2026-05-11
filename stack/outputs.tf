output "ecr_repository_url" {
  description = "ECR repository URL — use as the image base for docker push and task definitions"
  value       = aws_ecr_repository.api.repository_url
}

output "github_actions_api_ecr_push_role_arn" {
  description = "intentproof-api repository secret AWS_ECR_PUSH_ROLE_ARN — OIDC role to push release images on vX.Y.Z tags"
  value       = var.create_github_actions_api_ecr_push_role ? aws_iam_role.github_actions_api_ecr_push[0].arn : null
}

output "alb_dns_name" {
  description = "ALB DNS name — use for pre-DNS smoke testing before Route 53 alias is live"
  value       = aws_lb.api.dns_name
}

output "api_hostname" {
  description = "Production BASE_URL hostname (no scheme) — resolves once NS delegation + ACM validation complete"
  value       = "api.intentproof.io"
}

output "rds_endpoint" {
  description = "RDS instance endpoint (host:port) — private; reachable only from sg-tasks"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "sqs_queue_url" {
  description = "SQS verification queue URL — set as INTENTPROOF_SQS_QUEUE_URL"
  value       = aws_sqs_queue.verification.url
}

output "route53_nameservers" {
  description = "Nameservers for the Route 53 hosted zone — update registrar NS records to these"
  value       = aws_route53_zone.intentproof_io.name_servers
}

output "sns_alarm_topic_arn" {
  description = "SNS topic ARN for ingest alarms"
  value       = aws_sns_topic.alarms.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name — use with aws ecs execute-command for SSM Session Manager access"
  value       = aws_ecs_cluster.main.name
}
