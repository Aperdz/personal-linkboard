variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "backend_image" {
  description = "Full ECR image URI:tag for the backend — MUST be the exact same tag that was just verified working in dev"
  type        = string
}

variable "frontend_image" {
  type = string
}
