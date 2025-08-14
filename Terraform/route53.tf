# --- Route 53 Hosted Zone ---
data "aws_route53_zone" "primary_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

# --- Data Source for Primary ALB (eu-west-2) ---
data "aws_lb" "primary" {
  name = "k8s-auraflow-reactfro-6cd6adc8a3"
}

# --- Data Source for Secondary/DR ALB (us-east-1) ---
data "aws_lb" "secondary" {
  provider = aws.secondary
  name     = "k8s-auraflow-reactfro-c198b24cd0"
}

# --- Route 53 Health Check for Primary ALB (eu-west-2) ---
resource "aws_route53_health_check" "primary_alb_health_check" {
  fqdn              = data.aws_lb.primary.dns_name
  port              = var.health_check_port
  type              = var.health_check_protocol
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
  measure_latency   = true

  tags = {
    Name        = "${var.project_name}-primary-alb-health-check"
    Environment = "Production"
    Region      = var.primary_region
    Project     = var.project_name
  }
}

# --- Route 53 Health Check for Secondary/DR ALB (us-east-1) ---
resource "aws_route53_health_check" "secondary_alb_health_check" {
  fqdn              = data.aws_lb.secondary.dns_name
  port              = var.health_check_port
  type              = var.health_check_protocol
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
  measure_latency   = true

  tags = {
    Name        = "${var.project_name}-secondary-alb-health-check"
    Environment = "DisasterRecovery"
    Region      = var.secondary_region
    Project     = var.project_name
  }
}

# --- CloudWatch Log Group for Route 53 Health Check Logs ---
resource "aws_cloudwatch_log_group" "route53_health_check_logs" {
  name              = "/aws/route53/healthchecks/${var.project_name}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-route53-health-check-logs"
    Environment = "Production"
    Project     = var.project_name
  }
}

# --- CloudWatch Alarms for Health Check Failures ---
resource "aws_cloudwatch_metric_alarm" "primary_health_check_alarm" {
  alarm_name          = "${var.project_name}-primary-health-check-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This alarm monitors the health status of the primary ALB. Triggers on failure."
  alarm_actions       = [aws_sns_topic.health_check_notifications.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_alb_health_check.id
  }

  tags = {
    Name        = "${var.project_name}-primary-health-alarm"
    Environment = "Production"
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "secondary_health_check_alarm" {
  alarm_name          = "${var.project_name}-secondary-health-check-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "This alarm monitors the health status of the secondary/DR ALB. Triggers on failure."
  alarm_actions       = [aws_sns_topic.health_check_notifications.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.secondary_alb_health_check.id
  }

  tags = {
    Name        = "${var.project_name}-secondary-health-alarm"
    Environment = "DisasterRecovery"
    Project     = var.project_name
  }
}

# --- Route 53 Record Set: Primary (eu-west-2) ---
resource "aws_route53_record" "app_primary_record" {
  zone_id = data.aws_route53_zone.primary_hosted_zone.zone_id
  name    = var.app_subdomain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.primary.dns_name
    zone_id                = data.aws_lb.primary.zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "PRIMARY"
  }
  health_check_id = aws_route53_health_check.primary_alb_health_check.id
  set_identifier  = "primary"
}

# --- Route 53 Record Set: Secondary (us-east-1) ---
resource "aws_route53_record" "app_secondary_record" {
  zone_id = data.aws_route53_zone.primary_hosted_zone.zone_id
  name    = var.app_subdomain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.secondary.dns_name
    zone_id                = data.aws_lb.secondary.zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "SECONDARY"
  }
  health_check_id = aws_route53_health_check.secondary_alb_health_check.id
  set_identifier  = "secondary"
}

# --- Optional: CNAME for www subdomain ---
resource "aws_route53_record" "www_cname" {
  count   = var.create_www_cname ? 1 : 0
  zone_id = data.aws_route53_zone.primary_hosted_zone.zone_id
  name    = "www.${var.app_subdomain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["${var.app_subdomain_name}.${var.domain_name}"]
}

