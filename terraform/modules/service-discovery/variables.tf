variable "service_name" {
  description = "Service name (the Cloud Map service will be named sd-<service_name>)"
  type        = string
}

variable "namespace_name" {
  description = "Existing Cloud Map private DNS namespace name"
  type        = string
}

variable "cluster_key" {
  description = "Cluster key, used only for a clear error message"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}
