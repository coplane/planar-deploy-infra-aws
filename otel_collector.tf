locals {
  otel_metrics_receivers = var.enable_ecs_container_metrics ? "otlp, awsecscontainermetrics" : "otlp"
  otel_ecs_receiver_block = var.enable_ecs_container_metrics ? "      awsecscontainermetrics: {}\n" : ""
  otel_metrics_processors = var.enable_ecs_container_metrics ? "filter/ecs_metrics, batch" : "batch"
  otel_ecs_filter_block = var.enable_ecs_container_metrics ? <<-FILTER
      filter/ecs_metrics:
        metrics:
          include:
            match_type: strict
            metric_names:
              - ecs.task.cpu.reserved
              - ecs.task.cpu.utilized
              - ecs.task.memory.reserved
              - ecs.task.memory.utilized
              - container.cpu.reserved
              - container.cpu.utilized
              - container.memory.reserved
              - container.memory.utilized
  FILTER
  : ""

  # Extracted to a separate local so the heredoc isn't nested inside a ternary expression,
  # which causes Terraform to fail to parse the false branch.
  _otel_base_config_yaml = <<-YAML
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
${local.otel_ecs_receiver_block}

    processors:
      batch: {}
${local.otel_ecs_filter_block}

    exporters:
      otlphttp/metrics:
        endpoint: $${env:METRICS_ENDPOINT}
        headers:
          authorization: "Bearer $${env:TELEMETRY_TOKEN}"

    service:
      extensions: [health_check]
      pipelines:
        metrics:
          receivers: [${local.otel_metrics_receivers}]
          processors: [${local.otel_metrics_processors}]
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
