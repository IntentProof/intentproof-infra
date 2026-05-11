# CloudWatch alarms + SNS — RUNTIME_DECISION.md § 7
# Four alarms: ALB 5xx rate, RDS CPU, DLQ depth, outbox backlog*.
#
# * Outbox backlog (proof_ingest_outbox rows with published_at IS NULL > 100) cannot
#   be expressed as a standard CloudWatch metric — it requires a DB query. This is a
#   custom-metric follow-up: a Lambda or ECS scheduled task that queries Postgres and
#   publishes a custom CW metric. Tracked as a P3-B10 follow-up item.

resource "aws_sns_topic" "alarms" {
  name = "intentproof-ingest-alarms"

  tags = { Name = "intentproof-ingest-alarms" }
}

resource "aws_sns_topic_subscription" "ops_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
  # AWS will send a confirmation email; the subscription is PENDING until confirmed.
}

# ── Alarm 1: ALB 5xx rate > 1% over 5 min ────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "intentproof-ingest-alb-5xx"
  alarm_description   = "ALB 5xx error rate exceeded 1% over 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 1

  metric_query {
    id          = "error_rate"
    expression  = "100 * errors / MAX([errors, requests])"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = aws_lb.api.arn_suffix }
      period      = 300
      stat        = "Sum"
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = { LoadBalancer = aws_lb.api.arn_suffix }
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  treat_missing_data = "notBreaching"

  tags = { Name = "intentproof-alb-5xx" }
}

# ── Alarm 2: RDS CPU > 80% for 10 min ────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "intentproof-ingest-rds-cpu"
  alarm_description   = "RDS CPU exceeded 80% for 10 minutes — consider db.t4g.small"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  threshold           = 80
  statistic           = "Average"

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  dimensions  = { DBInstanceIdentifier = aws_db_instance.main.identifier }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  treat_missing_data = "notBreaching"

  tags = { Name = "intentproof-rds-cpu" }
}

# ── Alarm 3: DLQ depth > 0 for 5 min ─────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "intentproof-ingest-dlq-depth"
  alarm_description   = "Messages in DLQ — SQS delivery failure; inspect poison messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  threshold           = 0
  statistic           = "Sum"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions  = { QueueName = aws_sqs_queue.dlq.name }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  treat_missing_data = "notBreaching"

  tags = { Name = "intentproof-dlq-depth" }
}

# ── Alarm 4: outbox backlog ───────────────────────────────────────────────────
# Cannot be expressed as a standard CloudWatch metric without a custom publisher.
# Placeholder comment — implement as follow-up to P3-B10:
#
#   1. Create a Lambda (or ECS scheduled task) that runs every 5 min:
#      SELECT COUNT(*) FROM proof_ingest_outbox WHERE published_at IS NULL
#   2. Publish to a custom CW metric: intentproof/IngestPlane / OutboxUnpublishedCount
#   3. Alarm: OutboxUnpublishedCount > 100 for 10 min → SNS alarms topic
#
# Until then, CloudWatch Logs Insights can query /ecs/intentproof-ingest-api
# for log lines containing "outbox" to manually inspect backlog.
