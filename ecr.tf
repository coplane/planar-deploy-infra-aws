resource "aws_ecr_repository" "main" {
  count = var.repository_name != null ? 1 : 0

  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "main" {
  count      = var.repository_name != null ? 1 : 0
  repository = aws_ecr_repository.main[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Import the public demo image to the ECR repository
# ghcr.io/coplane/planar-demo-public:latest
resource "null_resource" "image_import" {
  count = var.repository_name != null && var.import_image_to_ecr && var.source_image != null ? 1 : 0

  triggers = {
    repository_url = aws_ecr_repository.main[0].repository_url
    source_image   = var.source_image
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.main[0].repository_url}
      docker pull --platform linux/amd64 ${var.source_image}
      docker tag ${var.source_image} ${aws_ecr_repository.main[0].repository_url}:latest
      docker push ${aws_ecr_repository.main[0].repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.main]
}
