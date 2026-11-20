# ============================================
# General Configuration Variables
# ============================================
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "log_retention_days" {
  type    = number
  default = 30
}
