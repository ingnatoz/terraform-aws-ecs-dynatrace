output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_service.service_name
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = module.alb.target_group_arn
}

output "log_group_name" {
  description = "Log group name"
  value       = module.cloudwatch.log_group_name
}

output "deployment_info" {
  description = "CI/CD info"
  value = {
    cluster_name       = local.cluster["cluster_name"]
    service_name       = local.config["service_name"]
    ecr_repository_url = module.ecr.repository_url
    region             = var.aws_region
  }
}
