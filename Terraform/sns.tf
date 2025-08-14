# --- SNS Topic for Health Check Notifications ---
resource "aws_sns_topic" "health_check_notifications" {
  name = var.sns_topic_name

  tags = {
    Name        = "${var.project_name}-health-check-notifications"
    Environment = "Production"
    Project     = var.project_name
  }
}

# --- SNS Topic Subscription ---
resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.health_check_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# --- SNS Topic Policy (allows CloudWatch to publish) ---
resource "aws_sns_topic_policy" "health_check_notifications_policy" {
  arn = aws_sns_topic.health_check_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.health_check_notifications.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# # --- Data source to get current AWS account ID ---
# data "aws_caller_identity" "current" {}