output "aws_region" {
  description = "Region used by this deployment."
  value       = var.aws_region
}

output "flask_repository_url" {
  description = "ECR repository URL for the Flask image."
  value       = aws_ecr_repository.flask.repository_url
}

output "express_repository_url" {
  description = "ECR repository URL for the Express image."
  value       = aws_ecr_repository.express.repository_url
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "express_url" {
  description = "Frontend URL (via ALB)."
  value       = "http://${aws_lb.main.dns_name}"
}

output "flask_api_url" {
  description = "Backend API URL (via ALB path /api/*)."
  value       = "http://${aws_lb.main.dns_name}/api/message"
}
