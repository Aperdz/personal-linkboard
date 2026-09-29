variable "project_name" {
  description = "Used as a prefix for resource names"
  type        = string
  default     = "linkboard"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}
