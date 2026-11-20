output "arn" {
  description = "ARN of the Cloud Map service discovery service"
  value       = aws_service_discovery_service.this.arn
}
