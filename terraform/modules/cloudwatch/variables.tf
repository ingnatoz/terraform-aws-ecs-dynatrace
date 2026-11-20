variable "service_name" {
  description = "Service name"
  type        = string
}

variable "retention_in_days" {
  description = "Log retention days"
  type        = number
  default     = 30
}

variable "log_group_name_override" {
  description = "Log group name (optional). If null/empty, a standard name is generated."
  type        = string
  default     = null
}

variable "enable_log_group_tags" {
  description = "If true, applies tags to the log group. Requires logs:TagResource permission."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}
