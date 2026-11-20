variable "service_name" {
  description = "Service name for the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Scan images on push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_count" {
  description = "Number of images to keep"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags for the repository"
  type        = map(string)
  default     = {}
}
