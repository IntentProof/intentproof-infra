# SQS — RUNTIME_DECISION.md § 5
# Standard queue (not FIFO), SSE-SQS encryption, DLQ with maxReceiveCount=5.

resource "aws_sqs_queue" "dlq" {
  name                      = "intentproof-verification-queue-dlq"
  message_retention_seconds = 1209600 # 14 days — keep failed messages for investigation

  sqs_managed_sse_enabled = true

  tags = { Name = "intentproof-verification-dlq" }
}

resource "aws_sqs_queue" "verification" {
  name                       = "intentproof-verification-queue"
  visibility_timeout_seconds = 60     # initial value; raise to ≥ worker p99 + margin in Phase 4
  message_retention_seconds  = 345600 # 4 days

  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "intentproof-verification-queue" }
}

# Allow the DLQ to receive messages from the main queue (required for redrive)
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.verification.arn]
  })
}
