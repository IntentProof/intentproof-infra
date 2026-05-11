resource "aws_ecr_repository" "api" {
  name                 = "intentproof-api"
  image_tag_mutability = "IMMUTABLE" # digest-pinned deploys per RUNTIME_DECISION.md § 2

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "intentproof-api" }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images; expire untagged after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Retain last 20 images (any tags)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
