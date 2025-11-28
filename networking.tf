resource "aws_security_group" "ecs_tasks" {
  name_prefix = "ecs-tasks${local.suffix}"
  vpc_id      = data.aws_vpc.main.id
  description = "Security group for ECS tasks"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "ecs-tasks${local.suffix}"
  })
}

resource "aws_security_group" "alb" {
  name_prefix            = "alb${local.suffix}"
  vpc_id                 = data.aws_vpc.main.id
  description            = "Security group for Application Load Balancer"
  revoke_rules_on_delete = true

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_internal ? [data.aws_vpc.main.cidr_block] : ["0.0.0.0/0"]
    description = var.alb_internal ? "HTTPS from VPC" : "HTTPS from internet"
  }

  tags = merge(local.common_tags, {
    Name = "alb${local.suffix}"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "aurora${local.suffix}"
  vpc_id      = data.aws_vpc.main.id
  description = "Security group for Aurora PostgreSQL Serverless v2"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "PostgreSQL from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "aurora${local.suffix}"
  })
}

resource "aws_security_group_rule" "alb_to_ecs" {
  type              = "egress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.main.cidr_block]
  security_group_id = aws_security_group.alb.id
  description       = "ALB to ECS tasks on port 8000"
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "ECS tasks from ALB"
}