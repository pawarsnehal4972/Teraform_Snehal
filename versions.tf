terraform {
  required_version = ">= 1.10.0"

  # Remote state in S3. bucket/region come from: terraform init -backend-config=backend.hcl
  backend "s3" {
    key = "part3-docker-ecs/terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 7.0"
    }
  }
}
