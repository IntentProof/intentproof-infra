# RDS PostgreSQL 16 — internal-beta spec from RUNTIME_DECISION.md § 4:
# db.t4g.micro, 20 GB gp3, single-AZ, PITR enabled, private subnets, encrypted.
# Trip-wire: flip multi_az = true before first external customer.

resource "aws_db_subnet_group" "main" {
  name        = "intentproof-db-subnet-group"
  description = "Private subnets for IntentProof RDS - spans 2 AZs for multi-AZ readiness"
  subnet_ids  = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = { Name = "intentproof-db-subnet-group" }
}

resource "aws_db_parameter_group" "postgres16" {
  name        = "intentproof-postgres16"
  family      = "postgres16"
  description = "IntentProof PostgreSQL 16 parameter group"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries > 1s for slow-query visibility
  }

  tags = { Name = "intentproof-postgres16" }
}

resource "aws_db_instance" "main" {
  identifier = "intentproof-ingest"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  db_name  = "intentproof"
  username = "intentproof"
  password = var.db_password

  # Storage — RUNTIME_DECISION.md § 4
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true # AWS-managed KMS key

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Availability — single-AZ for internal beta; flip to true before external customers
  multi_az = false

  # Backups + PITR — target RPO via RUNTIME_DECISION; Free Tier: set rds_backup_retention_period = 0 in tfvars.
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "04:00-05:00" # UTC
  maintenance_window      = "sun:05:30-sun:07:00"

  # Performance Insights for slow-query visibility (RUNTIME_DECISION.md § 7)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  parameter_group_name = aws_db_parameter_group.postgres16.name

  skip_final_snapshot       = false
  final_snapshot_identifier = "intentproof-ingest-final-snapshot"
  deletion_protection       = true

  tags = { Name = "intentproof-ingest" }
}
