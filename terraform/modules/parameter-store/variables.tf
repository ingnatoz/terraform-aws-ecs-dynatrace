variable "parameters" {
  description = "List of SSM parameters to create"
  type = list(object({
    parameter_name  = string
    parameter_value = string
    description     = optional(string)
    type            = optional(string, "String")
    data_type       = optional(string, "text")
  }))

  validation {
    condition     = alltrue([for p in var.parameters : contains(["String", "StringList"], p.type)])
    error_message = "Parameter type must be String or StringList (SecureString is not supported in this flow)."
  }
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}
