# =====================================================================
# ECS cluster (Fargate), IAM, logs, task definitions, services
# =====================================================================
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "flask" {
  name              = "/ecs/${var.project_name}/flask-backend"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "express" {
  name              = "/ecs/${var.project_name}/express-frontend"
  retention_in_days = var.log_retention_days
}

# Task execution role: lets ECS pull from ECR and write to CloudWatch Logs.
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ---------- Flask ----------
resource "aws_ecs_task_definition" "flask" {
  family                   = "${var.project_name}-flask"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "flask-backend"
    image     = "${aws_ecr_repository.flask.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.flask_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = tostring(var.flask_port) },
      { name = "STUDENT_NAME", value = "Snehal" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.flask.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "flask"
      }
    }
  }])
}

resource "aws_ecs_service" "flask" {
  name                              = "${var.project_name}-flask-svc"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.flask.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true # public subnets + no NAT gateway (saves cost); SG still restricts access to the ALB
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask.arn
    container_name   = "flask-backend"
    container_port   = var.flask_port
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener_rule.flask_api]
}

# ---------- Express ----------
resource "aws_ecs_task_definition" "express" {
  family                   = "${var.project_name}-express"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "express-frontend"
    image     = "${aws_ecr_repository.express.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.express_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = tostring(var.express_port) },
      # /api/* is routed to Flask by the ALB; this URL is used by Express for its /status check.
      { name = "BACKEND_URL", value = "http://${aws_lb.main.dns_name}" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.express.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "express"
      }
    }
  }])
}

resource "aws_ecs_service" "express" {
  name                              = "${var.project_name}-express-svc"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.express.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.express.arn
    container_name   = "express-frontend"
    container_port   = var.express_port
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener_rule.flask_api]
}
