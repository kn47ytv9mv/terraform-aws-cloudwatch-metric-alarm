variable "alarm_name" {
  default     = null
  description = "Name of the alarm, unique within the account and region. If null, a unique name is generated — though a descriptive name is worth setting here, since it is what appears in the notification an operator actually reads."
}

variable "alarm_description" {
  default     = null
  description = "Description carried into the notification. Worth stating what is wrong and what to do about it, since this is often all the context an operator has at three in the morning."
}

variable "namespace" {
  default     = null
  description = "CloudWatch namespace the metric lives in (e.g. 'AWS/EC2', 'AWS/RDS', 'AWS/ApplicationELB'). Omit when using metric_queries, which carry their own namespaces."
}

variable "metric_name" {
  default     = null
  description = "Name of the metric to watch (e.g. 'CPUUtilization', 'HTTPCode_Target_5XX_Count'). Omit when using metric_queries."
}

variable "dimensions" {
  default     = null
  description = "Dimensions narrowing the metric to one resource (e.g. { DBInstanceIdentifier = 'app' }). A metric published with dimensions cannot be alarmed on without specifying them — the alarm stays in INSUFFICIENT_DATA forever, which is the single most common reason an alarm never fires."
}

variable "statistic" {
  default     = null
  description = "How datapoints in each period are aggregated: 'Average', 'Sum', 'Minimum', 'Maximum', or 'SampleCount'. Mutually exclusive with extended_statistic. Prefer 'Maximum' or a high percentile over 'Average' for latency — an average hides the slow requests that actually hurt."
}

variable "extended_statistic" {
  default     = null
  description = "Percentile statistic to aggregate with (e.g. 'p99', 'p95'). Mutually exclusive with statistic."

  validation {
    condition     = var.statistic == null || var.extended_statistic == null
    error_message = "At most one of statistic or extended_statistic may be set."
  }
}

variable "period" {
  default     = 300
  description = "Seconds each datapoint covers. Must be 10, 30, or a multiple of 60. Below 60 requires the metric to be published at high resolution, and bills more."
}

variable "unit" {
  default     = null
  description = "Unit the metric is published in (e.g. 'Percent', 'Count', 'Seconds'). Setting the wrong unit matches no datapoints and leaves the alarm in INSUFFICIENT_DATA. If null, any unit matches."
}

variable "comparison_operator" {
  default     = null
  description = "How the statistic is compared to the threshold: 'GreaterThanThreshold', 'GreaterThanOrEqualToThreshold', 'LessThanThreshold', 'LessThanOrEqualToThreshold', or one of the anomaly-detection band operators ('LessThanLowerOrGreaterThanUpperThreshold', 'GreaterThanUpperThreshold', 'LessThanLowerThreshold')."
}

variable "threshold" {
  default     = null
  description = "Value the statistic is compared against. Mutually exclusive with threshold_metric_id, which compares against an anomaly-detection band instead."
}

variable "threshold_metric_id" {
  default     = null
  description = "ID of a metric_queries entry producing an anomaly-detection band (an ANOMALY_DETECTION_BAND expression), used instead of a static threshold. Pair with one of the band comparison operators."

  validation {
    condition     = var.threshold == null || var.threshold_metric_id == null
    error_message = "At most one of threshold or threshold_metric_id may be set."
  }
}

variable "evaluation_periods" {
  default     = 1
  description = "Number of most-recent periods evaluated against the threshold. Raising it above 1, together with datapoints_to_alarm, is how a brief spike is stopped from paging anyone."
}

variable "datapoints_to_alarm" {
  default     = null
  description = "How many of the evaluation_periods datapoints must breach for the alarm to fire — the 'M out of N' form. If null, every period must breach."
}

variable "treat_missing_data" {
  default     = "missing"
  description = "How a period with no data is treated: 'missing' (ignored, the default and AWS's own), 'notBreaching', 'breaching', or 'ignore'. For a metric only published when something happens — an error count, say — 'missing' means the alarm never recovers to OK on its own; 'notBreaching' is usually what is wanted there."

  validation {
    condition     = contains(["missing", "notBreaching", "breaching", "ignore"], var.treat_missing_data)
    error_message = "treat_missing_data must be one of 'missing', 'notBreaching', 'breaching', or 'ignore'."
  }
}

variable "alarm_actions" {
  default     = null
  description = "ARNs notified when the alarm enters ALARM — typically an SNS topic from terraform-aws-sns-topic. An alarm with no actions is a dashboard widget, not a notification: it changes state silently and tells nobody."
}

variable "ok_actions" {
  default     = null
  description = "ARNs notified when the alarm returns to OK. Worth setting alongside alarm_actions so an operator learns the problem cleared without having to go look."
}

variable "insufficient_data_actions" {
  default     = null
  description = "ARNs notified when the alarm enters INSUFFICIENT_DATA. Usually left unset — this state most often means a misconfigured dimension or a resource that no longer exists, not an incident."
}

variable "actions_enabled" {
  default     = null
  description = "Whether the alarm's actions fire at all. Setting false keeps the alarm evaluating and visible while suppressing notifications, which is how an alarm is muted during planned work. If null, AWS's own default (enabled) applies."
}

variable "metric_queries" {
  default     = []
  description = "Metric math or multi-metric queries, used instead of the single-metric variables above. Each entry has an id referenced by other expressions; either a metric block (a real CloudWatch metric) or an expression (math over other IDs, or ANOMALY_DETECTION_BAND). Exactly one entry must set return_data true — that is the value the alarm evaluates."
  type = list(object({
    id          = string
    expression  = optional(string)
    label       = optional(string)
    period      = optional(number)
    return_data = optional(bool)
    account_id  = optional(string)
    metric = optional(object({
      metric_name = string
      period      = number
      stat        = string
      namespace   = optional(string)
      dimensions  = optional(map(string))
      unit        = optional(string)
    }))
  }))

  validation {
    condition     = alltrue([for q in var.metric_queries : (q.expression == null) != (q.metric == null)])
    error_message = "Each metric_queries entry must set exactly one of expression or metric."
  }

  validation {
    condition     = length(var.metric_queries) == 0 || length([for q in var.metric_queries : q if q.return_data == true]) == 1
    error_message = "Exactly one metric_queries entry must set return_data to true — that is the value the alarm evaluates."
  }
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the alarm."
}
