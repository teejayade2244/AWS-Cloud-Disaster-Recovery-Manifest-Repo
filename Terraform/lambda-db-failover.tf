# --- IAM Role for Lambda Function ---
resource "aws_iam_role" "db_failover_lambda_role" {
  provider = aws.secondary  # Lambda is deployed in DR region
  
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
  provider = aws.secondary  # Must match the role provider
  
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
        Resource = [
          "arn:aws:rds:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:db:${var.dr_db_replica_id}",
          "arn:aws:rds:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:db:*"
        ]
      },
      # Secrets Manager update permissions (specific to DR credentials secret)
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetSecretValue" 
        ],
        Resource = "arn:aws:secretsmanager:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:secret:${var.dr_db_credentials_secret_name}*"
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
  provider = aws.secondary  # Must match the role and policy providers
  
  role       = aws_iam_role.db_failover_lambda_role.name
  policy_arn = aws_iam_policy.db_failover_lambda_policy.arn
}

# --- Create Lambda deployment package using archive_file ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

# --- Lambda Function for DB Failover ---
resource "aws_lambda_function" "db_failover_lambda" {
  provider = aws.secondary  # Lambda deployed in DR region (us-east-1)
  
  depends_on = [aws_iam_role_policy_attachment.db_failover_lambda_attach]

  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-db-failover-lambda"
  role             = aws_iam_role.db_failover_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"  # Updated to latest version
  timeout          = 900           # 15 minutes for long-running promotions
  memory_size      = 512           # Increased memory

  environment {
    variables = {
      PRIMARY_HEALTH_ALARM_NAME      = var.primary_health_alarm_name
      DR_DB_REPLICA_ID               = var.dr_db_replica_id
      DR_DB_CREDENTIALS_SECRET_NAME  = var.dr_db_credentials_secret_name
      NOTIFICATION_TOPIC_ARN         = var.notification_topic_arn
    }
  }

  # Use the archive_file hash
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-db-failover-lambda"
    Environment = "DisasterRecovery"
  }
}

# --- SNS Topic Subscription to Lambda ---
resource "aws_sns_topic_subscription" "db_failover_lambda_subscription" {
  provider = aws.secondary  # Must be in the same region as the SNS topic
  
  topic_arn = aws_sns_topic.health_check_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.db_failover_lambda.arn
  confirmation_timeout_in_minutes = 5
}

# --- Lambda Permission to be Invoked by SNS ---
resource "aws_lambda_permission" "allow_sns_to_invoke_lambda" {
  provider = aws.secondary  # Must match the Lambda provider
  
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_failover_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.health_check_notifications.arn
}