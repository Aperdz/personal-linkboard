terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "linkboard-terraform-state" 
    key            = "dev/terraform.tfstate" 
    
    region         = "ap-southeast-1"
    dynamodb_table = "linkboard-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
