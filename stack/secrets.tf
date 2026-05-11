# Secrets Manager — RUNTIME_DECISION.md § 6
# DATABASE_URL and API_KEYS injected into Fargate tasks via secrets[] in task definition.

locals {
  db_url = "postgresql+psycopg://${aws_db_instance.main.username}:${var.db_password}@${aws_db_instance.main.endpoint}/intentproof?sslmode=require"
}

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "intentproof/beta/database-url"
  description             = "INTENTPROOF_DATABASE_URL for the ingest API (Fargate task)"
  recovery_window_in_days = 7

  tags = { Name = "intentproof-database-url" }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = local.db_url
}

resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "intentproof/beta/api-keys"
  description             = "INTENTPROOF_API_KEYS JSON — dev/internal-beta only; migrate to hashed DB table before external customers (P3-B4 follow-up)"
  recovery_window_in_days = 7

  tags = { Name = "intentproof-api-keys" }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id     = aws_secretsmanager_secret.api_keys.id
  secret_string = var.api_keys_json
}
