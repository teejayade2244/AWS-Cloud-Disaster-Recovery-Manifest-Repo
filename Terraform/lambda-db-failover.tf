# lambda-db-failover.tf

# --- IAM Role for Lambda Function ---
resource "aws_iam_role" "db_failover_lambda_role" {
  name = "${var.project_name}-db-failover-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-db-failover-lambda-role"
    Environment = "DisasterRecovery" # Lambda runs in DR region
  }
}

# --- IAM Policy for Lambda Function ---
resource "aws_iam_policy" "db_failover_lambda_policy" {
  name        = "${var.project_name}-db-failover-lambda-policy"
  description = "Policy for Lambda to promote RDS and update Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs permissions
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      # RDS Promotion permissions (specific to DR replica)
      {
        Effect   = "Allow",
        Action   = [
          "rds:PromoteReadReplica",
          "rds:DescribeDBInstances" 
        ],
        Resource = "arn:aws:rds:${var.secondary_aws_region}:${data.aws_caller_identity.current.account_id}:db:${var.dr_db_replica_id}"
      },
      # Secrets Manager update permissions (specific to DR credentials secret)
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetSecretValue" 
        ],
        Resource = "arn:aws:secretsmanager:${var.secondary_aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.dr_db_credentials_secret_name}"
      },
      # SNS publish permissions for notification (Lambda sends notifications)
      {
        Effect   = "Allow",
        Action   = "sns:Publish",
        Resource = var.notification_topic_arn 
      }
    ]
  })
}

# --- Attach Policy to Role ---
resource "aws_iam_role_policy_attachment" "db_failover_lambda_attach" {
  role       = aws_iam_role.db_failover_lambda_role.name
  policy_arn = aws_iam_policy.db_failover_lambda_policy.arn
}

# --- Lambda Function for DB Failover ---
resource "aws_lambda_function" "db_failover_lambda" {
  filename      = "lambda_function.zip"
  function_name = "${var.project_name}-db-failover-lambda"
  role          = aws_iam_role.db_failover_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300 
  memory_size   = 256 

  # Environment variables for the Lambda function
  environment {
    variables = {
      AWS_REGION                     = var.secondary_aws_region 
      PRIMARY_HEALTH_ALARM_NAME      = var.primary_health_alarm_name
      DR_DB_REPLICA_ID               = var.dr_db_replica_id
      DR_DB_CREDENTIALS_SECRET_NAME  = var.dr_db_credentials_secret_name
      NOTIFICATION_TOPIC_ARN         = var.notification_topic_arn # New!
    }
  }

  source_code_hash = filebase64sha256("lambda_function.zip")

  # Create the ZIP file containing the Lambda code
  provisioner "local-exec" {
    command = <<EOT
      zip -j lambda_function.zip "${path.module}/lambda_function.py"
    EOT
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      filename,         
      source_code_hash, 
    ]
  }

  tags = {
    Name        = "${var.project_name}-db-failover-lambda"
    Environment = "DisasterRecovery"
  }
}

# --- SNS Topic Subscription to Lambda ---
resource "aws_sns_topic_subscription" "db_failover_lambda_subscription" {
  topic_arn = aws_sns_topic.health_check_notifications.arn 
  protocol  = "lambda"
  endpoint  = aws_lambda_function.db_failover_lambda.arn
  confirmation_timeout_in_minutes = 1
}

# --- Lambda Permission to be Invoked by SNS ---
resource "aws_lambda_permission" "allow_sns_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_failover_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.health_check_notifications.arn
}
