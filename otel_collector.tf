locals {
  otel_base_config = var.telemetry_enabled ? <<-YAML
extensions:
  health_check:
    endpoint: 0.0.0.0:13133

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  awsecscontainermetrics: {}

processors:
  batch: {}

exporters:
  otlphttp/metrics:
    endpoint: $${env:METRICS_ENDPOINT}

service:
  extensions: [health_check]
  pipelines:
    metrics:
      receivers: [otlp, awsecscontainermetrics]
      processors: [batch]
      exporters: [otlphttp/metrics]
  YAML
  : null
}

resource "aws_cloudwatch_log_group" "otel_collector" {
  count = var.telemetry_enabled ? 1 : 0

  name              = "/ecs/otel-collector${local.suffix}"
  retention_in_days = 7

  tags = local.common_tags
}
