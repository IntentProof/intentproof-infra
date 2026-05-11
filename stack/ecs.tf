# ECS Fargate — RUNTIME_DECISION.md § 2
# 0.25 vCPU / 0.5 GB, min=1/max=2, public subnets with public IP, rolling deploy.

resource "aws_ecs_cluster" "main" {
  name = "intentproof"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "intentproof" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/intentproof-ingest-api"
  retention_in_days = 30

  tags = { Name = "intentproof-ingest-api-logs" }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "intentproof-ingest-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # 0.25 vCPU
  memory                   = 512 # 0.5 GB

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      # Secrets injected from Secrets Manager — never in plaintext env or logs
      secrets = [
        {
          name      = "INTENTPROOF_DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.database_url.arn
        },
        {
          name      = "INTENTPROOF_API_KEYS"
          valueFrom = aws_secretsmanager_secret.api_keys.arn
        }
      ]

      environment = [
        {
          name  = "INTENTPROOF_SQS_QUEUE_URL"
          value = aws_sqs_queue.verification.url
        },
        {
          name  = "INTENTPROOF_AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "INTENTPROOF_ENV"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:8000/health || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30 # allow time for alembic upgrade head at startup
      }

      essential = true
    }
  ])

  tags = { Name = "intentproof-ingest-api" }
}

resource "aws_ecs_service" "api" {
  name            = "intentproof-ingest-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"

  desired_count = 1

  # Rolling deploy: min 100% / max 200% — bad image cannot drop below 1 healthy task
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # SSM Session Manager requires execute_command_configuration
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true # required for ECR pull / SQS / Secrets Manager without NAT
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8000
  }

  # Wait for ALB target group to exist before creating service
  depends_on = [aws_lb_listener.https]

  lifecycle {
    # image_tag changes are applied via task definition updates, not service recreation
    ignore_changes = [task_definition]
  }

  tags = { Name = "intentproof-ingest-api" }
}

# ── Autoscaling ───────────────────────────────────────────────────────────────
# Target: ALB request count per target 20 req/s, CPU 70% ceiling.
# Min=1 (always running for cold-start avoidance), max=2.

resource "aws_appautoscaling_target" "api" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_requests" {
  name               = "intentproof-ingest-alb-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 20 # req/s per target

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.api.arn_suffix}/${aws_lb_target_group.api.arn_suffix}"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "intentproof-ingest-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70 # CPU percent

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
