variable "project_name" {
  type = string
}

variable "environment" {
  description = "e.g. \"dev\" or \"prod\" — used in resource names and tags"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "image" {
  description = "Full image URI INCLUDING tag, e.g. 123456789.dkr.ecr.ap-southeast-1.amazonaws.com/linkboard-backend:abc1234"
  type        = string
}

variable "container_port" {
  type    = number
  default = 4000
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU, 512 = 0.5 vCPU, etc.)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Baseline number of running tasks — same idea as k8s 'replicas'"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Floor for autoscaling — same idea as k8s HPA minReplicas"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Ceiling for autoscaling — same idea as k8s HPA maxReplicas"
  type        = number
  default     = 6
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "env_vars" {
  description = "Plain (non-secret) environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Map of container env var name -> ARN of the Secrets Manager secret (or SSM parameter) supplying it. Values are injected by ECS at runtime, never written into the task definition or logs in plaintext."
  type        = map(string)
  default     = {}
}
