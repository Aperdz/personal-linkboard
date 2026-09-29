variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "backend_image" {
  description = "Full ECR image URI:tag for the backend — passed in by CI, e.g. via -var"
  type        = string
}

variable "frontend_image" {
  description = "Full ECR image URI:tag for the frontend — passed in by CI"
  type        = string
}
