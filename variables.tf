variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "tf-assignment-part3"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "image_tag" {
  description = "Docker image tag pushed to ECR and deployed by ECS."
  type        = string
  default     = "latest"
}

variable "flask_port" {
  description = "Container port of the Flask backend."
  type        = number
  default     = 5000
}

variable "express_port" {
  description = "Container port of the Express frontend."
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks per ECS service."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 7
}
