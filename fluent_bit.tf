locals {
  fluent_bit_config_s3_key = "config/fluent-bit.conf"

  # Parse metrics endpoint URL into Fluent Bit OUTPUT parameters
  _metrics_host = var.metrics_endpoint != null ? regex("^https?://([^/:]+)", var.metrics_endpoint)[0] : ""
  _metrics_port = var.metrics_endpoint != null ? (
    length(regexall("^https?://[^:]+:(\\d+)", var.metrics_endpoint)) > 0
    ? tonumber(regexall("^https?://[^:]+:(\\d+)", var.metrics_endpoint)[0][0])
    : (startswith(var.metrics_endpoint, "https://") ? 443 : 80)
  ) : 443
  _metrics_tls = var.metrics_endpoint != null && startswith(var.metrics_endpoint, "https://") ? "on" : "off"

  fluent_bit_config = var.telemetry_enabled ? <<-CONF
[SERVICE]
    Flush        5
    Daemon       Off
    Log_Level    info

# System metrics inputs
[INPUT]
    Name         cpu
    Tag          metrics.cpu
    Interval_Sec 30

[INPUT]
    Name         mem
    Tag          metrics.memory
    Interval_Sec 30

# Forward metrics to Coplane telemetry gateway
[OUTPUT]
    Name         opentelemetry
    Match        metrics.*
    Host         ${local._metrics_host}
    Port         ${local._metrics_port}
    Metrics_uri  /v1/metrics
    tls          ${local._metrics_tls}

%{if var.log_output_config != null}
# Customer-configured log routing
${var.log_output_config}
%{else}
# Default: CloudWatch log routing
[OUTPUT]
    Name              cloudwatch_logs
    Match             *-firelens-*
    region            ${data.aws_region.current.id}
    log_group_name    ${aws_cloudwatch_log_group.ecs.name}
    log_stream_prefix app-
    auto_create_group false
%{endif}
  CONF
  : null
}

resource "aws_s3_object" "fluent_bit_config" {
  count = var.telemetry_enabled ? 1 : 0

  bucket  = aws_s3_bucket.app_bucket.id
  key     = local.fluent_bit_config_s3_key
  content = local.fluent_bit_config
  etag    = md5(local.fluent_bit_config)

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "fluent_bit" {
  count = var.telemetry_enabled ? 1 : 0

  name              = "/ecs/fluent-bit${local.suffix}"
  retention_in_days = 7

  tags = local.common_tags
}
