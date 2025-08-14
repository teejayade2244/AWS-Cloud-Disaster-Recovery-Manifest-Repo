resource "aws_sns_topic" "health_check_notifications" {
  provider = aws.secondary  # MUST be in us-east-1 to receive CloudWatch alarms
  name     = "${var.project_name}-route53-health-notifications"

  tags = {
    Name        = "${var.project_name}-health-notifications"
    Environment = "Production"
    Project     = var.project_name
  }
}

# --- SNS Topic Subscription for Email Notifications ---
resource "aws_sns_topic_subscription" "health_check_email" {
  provider  = aws.secondary  # MUST be in us-east-1
  topic_arn = aws_sns_topic.health_check_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email  
}

#  SNS Topic Policy to allow CloudWatch to publish ---
resource "aws_sns_topic_policy" "health_check_notifications_policy" {
  provider = aws.secondary
  arn      = aws_sns_topic.health_check_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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

# Data source to get current AWS account ID
# data "aws_caller_identity" "current" {
#   provider = aws.secondary
# }