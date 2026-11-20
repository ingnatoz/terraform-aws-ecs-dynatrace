output "parameter_arns" {
  description = "ARNs of the created parameters"
  value       = { for name, p in aws_ssm_parameter.this : name => p.arn }
}

output "parameter_names" {
  description = "Names of the created parameters"
  value       = keys(aws_ssm_parameter.this)
}
