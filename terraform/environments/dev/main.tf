module "backend" {
  source = "../../modules/ecs-service"

  project_name   = "linkboard"
  environment    = "dev"
  aws_region     = var.aws_region
  image          = var.backend_image
  container_port = 4000

  # Dev is intentionally small/cheap — this is where you iterate fast,
  # not where you need production-grade capacity.
  cpu           = 256
  memory        = 512
  desired_count = 1
  min_capacity  = 1
  max_capacity  = 2

  env_vars = {
    ENV = "development"
  }

  # Real secrets (DB connection strings etc.) should come from Secrets
  # Manager, referenced like this — never hardcoded here:
  # secrets = {
  #   MONGO_URI = "arn:aws:secretsmanager:ap-southeast-1:123456789:secret:linkboard/dev/mongo-uri"
  # }
}

module "frontend" {
  source = "../../modules/ecs-service"

  project_name   = "linkboard"
  environment    = "dev-frontend"
  aws_region     = var.aws_region
  image          = var.frontend_image
  container_port = 3000

  cpu           = 256
  memory        = 512
  desired_count = 1
  min_capacity  = 1
  max_capacity  = 2

  health_check_path = "/"

  env_vars = {
    ENV = "development"
  }
}

output "backend_url" {
  value = "http://${module.backend.alb_dns_name}"
}

output "frontend_url" {
  value = "http://${module.frontend.alb_dns_name}"
}
