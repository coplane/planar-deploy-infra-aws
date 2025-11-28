resource "aws_db_subnet_group" "main" {
  name       = "aurora-subnet-group${local.suffix}"
  subnet_ids = var.subnets

  tags = merge(local.common_tags, {
    Name = "aurora-subnet-group${local.suffix}"
  })
}

resource "aws_rds_cluster" "main" {
  cluster_identifier      = "aurora-pg${local.suffix}"
  engine                  = "aurora-postgresql"
  engine_version          = "16.6"
  database_name           = "appdb"
  master_username         = "dbadmin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = null
  backup_retention_period = var.backup_retention_days
  preferred_backup_window = "03:00-04:00"
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  storage_encrypted   = true
  deletion_protection = var.stage == "prod" ? true : false
  skip_final_snapshot = var.stage != "prod" ? true : false
  final_snapshot_identifier = var.stage == "prod" ? "aurora-pg${local.suffix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  serverlessv2_scaling_configuration {
    max_capacity = var.aurora_max_capacity
    min_capacity = var.aurora_min_capacity
  }

  enable_http_endpoint = true

  tags = merge(local.common_tags, {
    Name = "aurora-pg${local.suffix}"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  identifier         = "aurora-pg${local.suffix}-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = merge(local.common_tags, {
    Name = "aurora-pg${local.suffix}-writer"
  })
}

resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}