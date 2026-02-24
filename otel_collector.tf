locals {
  # Extracted to a separate local so the heredoc isn't nested inside a ternary expression,
  # which causes Terraform to fail to parse the false branch.
  _otel_base_config_yaml = <<-YAML
    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
        path: /health/status

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

  otel_base_config = var.telemetry_enabled ? local._otel_base_config_yaml : null
}

resource "aws_cloudwatch_log_group" "otel_collector" {
  count = var.telemetry_enabled ? 1 : 0

  name              = "/ecs/otel-collector${local.suffix}"
  retention_in_days = 7

  tags = local.common_tags
}
