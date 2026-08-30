# =============================================================================
# Shared ECR repository — created ONCE, used by both dev and prod.
#
# Why shared, not per-environment: the whole point of "build once, promote
# the same artifact" is that dev and prod run the EXACT same image bytes,
# just a different tag/deployment. If each environment had its own ECR repo,
# you'd risk rebuilding the image differently for prod (different deps
# resolving, different base image digest pulled, etc.) — defeating the
# purpose of promotion-based deployment.
#
# Apply this ONCE, manually or via its own pipeline step, before dev/prod
# environments are ever applied — they reference this repo's URL as an input.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state so this isn't just sitting on someone's laptop.
  # Create the S3 bucket + DynamoDB table ONE time, manually, before
  # running `terraform init` here (chicken-and-egg problem: you can't
  # store state in a bucket that doesn't exist yet).
  backend "s3" {
    bucket         = "linkboard-terraform-state"   # CHANGE to your real bucket name
    key            = "global/ecr/terraform.tfstate"
    region         = "ap-southeast-1"               # CHANGE to your region
    dynamodb_table = "linkboard-terraform-locks"    # CHANGE to your real table name
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "IMMUTABLE" # once a tag (e.g. a git SHA) is pushed, it can't be overwritten —
                                       # protects against "prod silently started running different code"

  image_scanning_configuration {
    scan_on_push = true # SECURITY: automatically scans every pushed image for known CVEs
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
  }
}

# Lifecycle policy: automatically delete untagged images after 7 days so
# ECR storage doesn't grow forever with leftover build artifacts. Tagged
# (real, promoted) images are never touched by this rule.
resource "aws_ecr_lifecycle_policy" "backend_cleanup" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "frontend_cleanup" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
