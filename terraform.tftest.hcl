mock_provider "aws" {}

run "statistic_and_extended_statistic_are_mutually_exclusive" {
  command = plan

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    statistic           = "Average"
    extended_statistic  = "p99"
  }

  expect_failures = [var.extended_statistic]
}

run "threshold_and_threshold_metric_id_are_mutually_exclusive" {
  command = plan

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
    threshold_metric_id = "ad1"
  }

  expect_failures = [var.threshold_metric_id]
}

run "invalid_treat_missing_data_is_rejected" {
  command = plan

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
    treat_missing_data  = "whatever"
  }

  expect_failures = [var.treat_missing_data]
}

run "metric_query_needs_exactly_one_of_expression_or_metric" {
  command = plan

  variables {
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    metric_queries = [
      {
        id          = "m1"
        expression  = "SUM(METRICS())"
        return_data = true
        metric = {
          metric_name = "CPUUtilization"
          period      = 300
          stat        = "Average"
        }
      },
    ]
  }

  expect_failures = [var.metric_queries]
}

run "exactly_one_metric_query_must_return_data" {
  command = plan

  variables {
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    metric_queries = [
      { id = "m1", metric = { metric_name = "CPUUtilization", period = 300, stat = "Average" } },
      { id = "m2", metric = { metric_name = "NetworkIn", period = 300, stat = "Average" } },
    ]
  }

  expect_failures = [var.metric_queries]
}

run "alarm_name_defaults_to_random_uuid" {
  command = apply

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource.alarm_name == random_uuid.resource.id
    error_message = "Leaving alarm_name unset should fall back to the generated random_uuid."
  }
}

run "defaults_are_conservative" {
  command = plan

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource.period == 300
    error_message = "The period should default to five minutes, the standard resolution AWS publishes most metrics at."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource.evaluation_periods == 1
    error_message = "evaluation_periods should default to 1."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource.treat_missing_data == "missing"
    error_message = "treat_missing_data should default to AWS's own 'missing' behavior rather than silently changing it."
  }
}

run "no_metric_queries_by_default" {
  command = plan

  variables {
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource.metric_query) == 0
    error_message = "Leaving metric_queries unset should emit no metric_query blocks."
  }
}

run "period_is_suppressed_when_metric_queries_are_used" {
  command = plan

  variables {
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    metric_queries = [
      {
        id          = "m1"
        return_data = true
        metric      = { metric_name = "CPUUtilization", namespace = "AWS/EC2", period = 300, stat = "Average" }
      },
    ]
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.resource.period == null
    error_message = "A metric-query alarm carries its period inside each query, and AWS rejects a top-level period alongside them."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.resource.metric_query) == 1
    error_message = "Each metric_queries entry should produce one metric_query block."
  }
}

run "actions_pass_through" {
  command = plan

  variables {
    alarm_name          = "app-cpu-high"
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    statistic           = "Average"
    threshold           = 80
    alarm_actions       = ["arn:aws:sns:us-east-1:123456789012:alerts"]
    ok_actions          = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  }

  assert {
    condition     = one(aws_cloudwatch_metric_alarm.resource.alarm_actions) == "arn:aws:sns:us-east-1:123456789012:alerts"
    error_message = "alarm_actions should pass through unchanged so the alarm actually notifies someone."
  }

  assert {
    condition     = one(aws_cloudwatch_metric_alarm.resource.ok_actions) == "arn:aws:sns:us-east-1:123456789012:alerts"
    error_message = "ok_actions should pass through unchanged."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    alarm_name          = "app-cpu-high"
    alarm_description   = "Application instances averaging over 80% CPU for 10 minutes."
    namespace           = "AWS/EC2"
    metric_name         = "CPUUtilization"
    dimensions          = { AutoScalingGroupName = "app" }
    statistic           = "Average"
    period              = 300
    evaluation_periods  = 2
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    alarm_actions       = ["arn:aws:sns:us-east-1:123456789012:alerts"]
    ok_actions          = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  }
}

run "readme_anomaly_detection_example" {
  command = plan

  variables {
    alarm_name          = "app-latency-anomalous"
    comparison_operator = "GreaterThanUpperThreshold"
    threshold_metric_id = "band"
    evaluation_periods  = 2

    metric_queries = [
      {
        id          = "latency"
        return_data = true
        metric = {
          metric_name = "TargetResponseTime"
          namespace   = "AWS/ApplicationELB"
          period      = 300
          stat        = "Average"
        }
      },
      {
        id         = "band"
        expression = "ANOMALY_DETECTION_BAND(latency, 2)"
        label      = "Expected range"
      },
    ]

    alarm_actions = ["arn:aws:sns:us-east-1:123456789012:alerts"]
  }
}
