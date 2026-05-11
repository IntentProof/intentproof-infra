# ALB — RUNTIME_DECISION.md § 3
# Internet-facing, HTTPS-only on :443 with ACM cert, HTTP :80 redirects to HTTPS.
# Health check: GET /health, 5s interval, 2 healthy / 2 unhealthy thresholds.

resource "aws_lb" "api" {
  name               = "intentproof-ingest"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  # Access logs — enable once an S3 bucket exists for log delivery
  # access_logs {
  #   bucket  = "intentproof-alb-logs"
  #   prefix  = "ingest-api"
  #   enabled = true
  # }

  tags = { Name = "intentproof-ingest-alb" }
}

resource "aws_lb_target_group" "api" {
  name        = "intentproof-ingest-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # required for Fargate awsvpc networking

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 5
    timeout             = 4
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = { Name = "intentproof-ingest-api-tg" }
}

# HTTP :80 → HTTPS redirect (optional; see var.alb_accept_http)
resource "aws_lb_listener" "http_redirect" {
  count = var.alb_accept_http ? 1 : 0

  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS :443 — ACM cert attached; forwards to target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.api.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
