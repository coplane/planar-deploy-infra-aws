data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "rotation_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "rotate-ecs-secret${local.suffix}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  memory_size      = 512
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300

  environment {
    variables = {
      CLUSTER_NAME = aws_ecs_cluster.main.name
      SERVICE_NAME = aws_ecs_service.main.name
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "rotation-lambda-role${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "rotation_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.rotation_handler.function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService"
        ]
        Resource = [
          aws_ecs_service.main.id
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/lambda/${aws_lambda_function.rotation_handler.function_name}:*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "secret_rotation" {
  name        = "capture-secret-rotation${local.suffix}"
  description = "Capture successful secret rotation"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["Secret Rotation State Change"]
    detail = {
      event = ["RotationSucceeded"]
      additionalEventData = {
        SecretId = [aws_rds_cluster.main.master_user_secret[0].secret_arn]
      }
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.secret_rotation.name
  target_id = "TriggerECSUpdate"
  arn       = aws_lambda_function.rotation_handler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.secret_rotation.arn
}
