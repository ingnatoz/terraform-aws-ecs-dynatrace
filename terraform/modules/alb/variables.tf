variable "service_name" {
  description = "Service name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB listener ARN"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

variable "health_check_interval" {
  description = "Health check interval"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Consecutive successful checks to be healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks to be unhealthy"
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP matcher for health check (e.g. 200, 200-299)"
  type        = string
  default     = "200"
}

variable "allowed_methods" {
  description = "Allowed HTTP methods for the listener rule. If empty, no condition is added."
  type        = list(string)
  default     = ["GET", "POST", "PUT", "OPTIONS"]
}

variable "path_pattern" {
  description = "Path pattern for the listener rule"
  type        = string
}

variable "listener_rule_priority" {
  description = "Listener rule priority"
  type        = number
  default     = null
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}
