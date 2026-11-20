resource "aws_cloudwatch_log_group" "this" {
  name              = coalesce(var.log_group_name_override, "/ecs/${var.service_name}")
  retention_in_days = var.retention_in_days

  tags = var.enable_log_group_tags ? var.tags : {}
}
