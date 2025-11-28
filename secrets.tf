resource "aws_secretsmanager_secret" "custom_secret" {
  name                    = "custom-secret${local.suffix}"
  description             = "Custom secret for application configuration"
  recovery_window_in_days = var.stage == "prod" ? 30 : 0

  tags = merge(local.common_tags, {
    Name = "custom-secret${local.suffix}"
  })
}

resource "aws_secretsmanager_secret_version" "custom_secret" {
  secret_id = aws_secretsmanager_secret.custom_secret.id
  secret_string = jsonencode({
    placeholder_key = "placeholder_value"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "registry_credentials" {
  name                    = "registry-credentials${local.suffix}"
  description             = "Container registry credentials for ECS image pull"
  recovery_window_in_days = var.stage == "prod" ? 30 : 0

  tags = merge(local.common_tags, {
    Name = "registry-credentials${local.suffix}"
  })
}

resource "aws_secretsmanager_secret_version" "registry_credentials" {
  secret_id = aws_secretsmanager_secret.registry_credentials.id
  secret_string = jsonencode({
    username = var.container_registry_username
    password = var.container_registry_password
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}