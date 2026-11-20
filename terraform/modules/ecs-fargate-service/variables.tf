variable "service_name" {
  description = "Service name"
  type        = string
}

variable "cluster_name" {
  description = "Existing ECS cluster name"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "task_cpu" {
  description = "Task-level CPU units"
  type        = number
}

variable "task_memory" {
  description = "Task-level memory in MB"
  type        = number
}

variable "main_cpu" {
  description = "Main container (service) CPU units"
  type        = number
}

variable "main_memory" {
  description = "Main container (service) memory in MB"
  type        = number
}

variable "dynatrace_cpu" {
  description = "Secondary container (Dynatrace) CPU units"
  type        = number
}

variable "dynatrace_memory" {
  description = "Secondary container (Dynatrace) memory in MB"
  type        = number
}

variable "dynatrace_oneagent_options_param" {
  description = "SSM parameter name for DT_ONEAGENT_OPTIONS (varies front/back)"
  type        = string
}

variable "dynatrace" {
  description = "Dynatrace OneAgent installer settings shared by all services. ssm_* values are SSM parameter names (starting with /); the module builds the full ARN with the current account and var.aws_region."
  type = object({
    installer_image   = optional(string, "public.ecr.aws/docker/library/alpine:3.23")
    arch              = optional(string, "x86")
    skip_tls_verify   = optional(bool, false)
    log_group_name    = optional(string, "/ecs/dynatrace-oneagent-installer")
    ssm_api_url       = string
    ssm_paas_token    = string
    ssm_network_zone  = string
    ssm_log_level_con = string
  })
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "Image tag"
  type        = string
  default     = "latest"
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "main_secrets" {
  description = "Main container secrets. valueFrom is the SSM parameter name; the module builds the full ARN with the current account and var.aws_region."
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "service_registry_arn" {
  description = "Cloud Map service ARN for service discovery. If null, no service_registries block is added."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
