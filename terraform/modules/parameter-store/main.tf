resource "aws_ssm_parameter" "this" {
  for_each = { for p in var.parameters : p.parameter_name => p }

  name        = each.value.parameter_name
  description = each.value.description
  type        = each.value.type
  data_type   = each.value.data_type
  value       = each.value.parameter_value

  tags = var.tags
}
