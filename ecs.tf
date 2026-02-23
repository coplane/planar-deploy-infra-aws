resource "aws_ecs_cluster" "main" {
  name = "app-cluster${local.suffix}"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/planar-service${local.suffix}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "main" {
  family                   = "planar-service${local.suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode(concat(
    [
      merge(
        {
          name  = "planar-app"
          image = var.repository_name != null ? "${aws_ecr_repository.main[0].repository_url}:latest" : "${var.container_registry_url}/${var.container_image_name}:${var.container_image_tag}"

          portMappings = [
            {
              containerPort = 8000
              hostPort      = 8000
            }
          ]

          logConfiguration = var.telemetry_enabled ? {
            logDriver = "awsfirelens"
            options   = {}
          } : {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
              "awslogs-region"        = data.aws_region.current.id
              "awslogs-stream-prefix" = "ecs"
            }
          }

          environment = [
            {
              name  = "DB_SECRET_NAME"
              value = aws_rds_cluster.main.master_user_secret[0].name
            },
            {
              name  = "DB_HOST"
              value = aws_rds_cluster.main.endpoint
            },
            {
              name  = "S3_BUCKET_NAME"
              value = aws_s3_bucket.app_bucket.bucket
            },
            {
              name  = "STAGE"
              value = var.stage
            },
            {
              name  = "APP_NAME"
              value = var.app_name
            },
            {
              name  = "CUSTOM_SECRET_NAME"
              value = aws_secretsmanager_secret.custom_secret.name
            },
            {
              name  = "WORKOS_CLIENT_ID"
              value = var.workos_client_id
            },
            {
              name  = "WORKOS_ORG_ID"
              value = var.workos_org_id
            }
          ]

          essential = true
        },
        var.container_registry_username != null && var.container_registry_password != null ? {
          repositoryCredentials = {
            credentialsParameter = aws_secretsmanager_secret.registry_credentials[0].arn
          }
        } : {}
      )
    ],
    var.telemetry_enabled ? [
      {
        name      = "log_router"
        image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
        essential = true

        firelensConfiguration = {
          type = "fluentbit"
          options = {
            "enable-ecs-log-metadata" = "true"
            "config-file-type"        = "s3"
            "config-file-value"       = "arn:aws:s3:::${aws_s3_bucket.app_bucket.id}/${local.fluent_bit_config_s3_key}"
          }
        }

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.fluent_bit[0].name
            "awslogs-region"        = data.aws_region.current.id
            "awslogs-stream-prefix" = "fluent-bit"
          }
        }

        secrets = [
          for name, arn in var.log_output_secrets : {
            name      = name
            valueFrom = arn
          }
        ]
      }
    ] : []
  ))

  tags = local.common_tags
}

resource "aws_lb" "main" {
  name               = "plb${local.suffix}"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.alb_subnets != null ? var.alb_subnets : var.subnets

  enable_deletion_protection = var.stage == "prod" ? true : false

  tags = local.common_tags
}

resource "aws_lb_target_group" "main" {
  name        = "ptg${local.suffix}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-499"
    path                = "/planar/v1/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 10
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_ecs_service" "main" {
  name            = "planar-service${local.suffix}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "planar-app"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.https,
  ]

  # Ignore changes to the task definition to prevent reverting a deployment made by an external tool (like a CI/CD pipeline pushing a new image tag)
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_web_acl_arn != null || var.create_waf ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn != null ? var.waf_web_acl_arn : aws_wafv2_web_acl.main[0].arn
}