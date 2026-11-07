provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Part      = "3-docker-ecs"
      ManagedBy = "Terraform"
      Owner     = "Snehal"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# =====================================================================
# ECR: one repository per application
# =====================================================================
resource "aws_ecr_repository" "flask" {
  name                 = "${var.project_name}-flask-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # allows `terraform destroy` even if images exist

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "express" {
  name                 = "${var.project_name}-express-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep only the 5 most recent images in each repository.
resource "aws_ecr_lifecycle_policy" "keep_recent" {
  for_each   = { flask = aws_ecr_repository.flask.name, express = aws_ecr_repository.express.name }
  repository = each.value

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
