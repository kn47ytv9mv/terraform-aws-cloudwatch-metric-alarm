resource "random_uuid" "resource" {}

resource "aws_cloudwatch_metric_alarm" "resource" {
  alarm_name        = coalesce(var.alarm_name, random_uuid.resource.id)
  alarm_description = var.alarm_description

  namespace          = var.namespace
  metric_name        = var.metric_name
  dimensions         = var.dimensions
  statistic          = var.statistic
  extended_statistic = var.extended_statistic
  period             = length(var.metric_queries) > 0 ? null : var.period
  unit               = var.unit

  comparison_operator = var.comparison_operator
  threshold           = var.threshold
  threshold_metric_id = var.threshold_metric_id

  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = var.datapoints_to_alarm
  treat_missing_data  = var.treat_missing_data

  alarm_actions             = var.alarm_actions
  ok_actions                = var.ok_actions
  insufficient_data_actions = var.insufficient_data_actions
  actions_enabled           = var.actions_enabled

  dynamic "metric_query" {
    for_each = var.metric_queries

    content {
      id          = metric_query.value.id
      expression  = metric_query.value.expression
      label       = metric_query.value.label
      period      = metric_query.value.period
      return_data = metric_query.value.return_data
      account_id  = metric_query.value.account_id

      dynamic "metric" {
        for_each = metric_query.value.metric[*]

        content {
          metric_name = metric.value.metric_name
          period      = metric.value.period
          stat        = metric.value.stat
          namespace   = metric.value.namespace
          dimensions  = metric.value.dimensions
          unit        = metric.value.unit
        }
      }
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID (name) of the alarm."
  value       = aws_cloudwatch_metric_alarm.resource.id
}

output "arn" {
  description = "The ARN of the alarm."
  value       = aws_cloudwatch_metric_alarm.resource.arn
}

output "alarm_name" {
  description = "The name of the alarm, as it appears in notifications."
  value       = aws_cloudwatch_metric_alarm.resource.alarm_name
}
