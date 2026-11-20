output "log_group_name" {
  description = "Log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "Log group ARN"
  value       = aws_cloudwatch_log_group.this.arn
}
