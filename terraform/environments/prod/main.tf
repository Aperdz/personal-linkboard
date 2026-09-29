module "backend" {
  source = "../../modules/ecs-service"

  project_name   = "linkboard"
  environment    = "prod"
  aws_region     = var.aws_region
  image          = var.backend_image
  container_port = 4000

  # Prod runs more capacity and a wider autoscaling range than dev —
  # this is the actual "production-grade" sizing.
  cpu           = 512
  memory        = 1024
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 8

  env_vars = {
    ENV = "production"
  }

  # secrets = {
  #   MONGO_URI = "arn:aws:secretsmanager:ap-southeast-1:123456789:secret:linkboard/prod/mongo-uri"
  # }
}

module "frontend" {
  source = "../../modules/ecs-service"

  project_name   = "linkboard"
  environment    = "prod-frontend"
  aws_region     = var.aws_region
  image          = var.frontend_image
  container_port = 3000

  cpu           = 512
  memory        = 1024
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 8

  health_check_path = "/"

  env_vars = {
    ENV = "production"
  }
}

output "backend_url" {
  value = "http://${module.backend.alb_dns_name}"
}

output "frontend_url" {
  value = "http://${module.frontend.alb_dns_name}"
}
