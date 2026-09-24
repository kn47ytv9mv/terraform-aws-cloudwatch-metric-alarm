# terraform-aws-cloudwatch-metric-alarm

Terraform module for a CloudWatch metric alarm — a threshold on a
metric that notifies an SNS topic when it is breached.

## Cost

Standard alarms bill per alarm-month, with a small free tier.
High-resolution alarms (`period` below 60) and metric-math or anomaly
detection alarms bill at higher rates, the latter per metric analyzed.
See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page
for current rates.

## Design

Pair with
[`terraform-aws-sns-topic`](https://github.com/kn47ytv9mv/terraform-aws-sns-topic),
whose ARN goes in `alarm_actions`. **An alarm with no actions is a
dashboard widget, not a notification** — it changes state silently and
tells nobody. Setting `ok_actions` to the same topic is worth doing so
an operator learns the problem cleared without going to look.

Alarms are split from the resources they watch rather than bundled into
each module, because one resource commonly has several alarms, each
independently tuned and owned, and an alarm frequently spans resources
through metric math. Bundling would also put a monitoring concern
inside every module in the family.

### Three ways an alarm silently never fires

These account for most alarms that exist but never do anything, and all
three are configuration rather than failure:

1. **Missing `dimensions`.** A metric published per-resource cannot be
   alarmed on without naming that resource. Without the dimension the
   alarm matches nothing and sits in `INSUFFICIENT_DATA` forever.
2. **A wrong `unit`.** A unit that does not match what the metric is
   published in matches no datapoints, with the same result. Leaving it
   null matches any unit and is usually safer.
3. **`treat_missing_data` left at `'missing'`** for a metric only
   published when something happens — an error count, say. The alarm
   fires correctly but then never returns to OK, because no data is not
   the same as zero. `'notBreaching'` is usually what is wanted there.

### Choosing a statistic

Prefer `'Maximum'` or `extended_statistic = 'p99'` over `'Average'` for
latency. An average over a five-minute period hides exactly the slow
requests worth alarming on.

`evaluation_periods` above 1, together with `datapoints_to_alarm`, is
how a brief spike is stopped from paging anyone — the "M out of N"
form.

### Metric math and anomaly detection

`metric_queries` replaces the single-metric variables for anything
computed across metrics. Exactly one entry sets `return_data = true`;
that is the value evaluated. For anomaly detection, add an
`ANOMALY_DETECTION_BAND` expression and point `threshold_metric_id` at
its ID instead of setting a static `threshold`. The module suppresses
the top-level `period` automatically when queries are used, since each
query carries its own and AWS rejects both together.

## Usage

```hcl
module "cpu_high" {
  source = "kn47ytv9mv/cloudwatch-metric-alarm/aws"

  alarm_name        = "app-cpu-high"
  alarm_description = "Application instances averaging over 80% CPU for 10 minutes."

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions  = { AutoScalingGroupName = module.group.name }

  statistic          = "Average"
  period             = 300
  evaluation_periods = 2

  comparison_operator = "GreaterThanThreshold"
  threshold           = 80

  alarm_actions = [module.alerts.arn]
  ok_actions    = [module.alerts.arn]
}
```

Or directly from this repository, alarming on anomalous latency rather
than a fixed threshold:

```hcl
module "latency_anomalous" {
  source = "github.com/kn47ytv9mv/terraform-aws-cloudwatch-metric-alarm"

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

  alarm_actions = [module.alerts.arn]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| alarm_name | Name of the alarm, unique per account and region. It is what appears in the notification an operator reads. | `null` | no |
| alarm_description | Description carried into the notification. Worth stating what is wrong and what to do about it. | `null` | no |
| namespace | CloudWatch namespace the metric lives in. Omit when using `metric_queries`. | `null` | no |
| metric_name | Name of the metric to watch. Omit when using `metric_queries`. | `null` | no |
| dimensions | Dimensions narrowing the metric to one resource. Omitting a required dimension leaves the alarm in `INSUFFICIENT_DATA` forever. | `null` | no |
| statistic | `'Average'`, `'Sum'`, `'Minimum'`, `'Maximum'`, or `'SampleCount'`. Mutually exclusive with `extended_statistic`. | `null` | no |
| extended_statistic | Percentile statistic (e.g. `'p99'`). Mutually exclusive with `statistic`. | `null` | no |
| period | Seconds each datapoint covers. 10, 30, or a multiple of 60. Below 60 requires high-resolution metrics and bills more. | `300` | no |
| unit | Unit the metric is published in. A wrong unit matches no datapoints. | `null` | no |
| comparison_operator | How the statistic is compared to the threshold, including the anomaly-detection band operators. | `null` | no |
| threshold | Value compared against. Mutually exclusive with `threshold_metric_id`. | `null` | no |
| threshold_metric_id | ID of a `metric_queries` entry producing an anomaly-detection band. Mutually exclusive with `threshold`. | `null` | no |
| evaluation_periods | Number of most-recent periods evaluated. | `1` | no |
| datapoints_to_alarm | How many of those must breach — the "M out of N" form. | `null` | no |
| treat_missing_data | `'missing'`, `'notBreaching'`, `'breaching'`, or `'ignore'`. | `"missing"` | no |
| alarm_actions | ARNs notified on ALARM, typically an SNS topic. An alarm with no actions notifies nobody. | `null` | no |
| ok_actions | ARNs notified when the alarm returns to OK. | `null` | no |
| insufficient_data_actions | ARNs notified on INSUFFICIENT_DATA. Usually left unset. | `null` | no |
| actions_enabled | Whether actions fire at all. False mutes the alarm while keeping it evaluating. | `null` | no |
| metric_queries | Metric math or multi-metric queries. Exactly one entry must set `return_data` true. | `[]` | no |
| tags | A map of tags to assign to the alarm. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID (name) of the alarm. |
| arn | The ARN of the alarm. |
| alarm_name | The name of the alarm, as it appears in notifications. |

## License

MIT — see [LICENSE.md](LICENSE.md).
