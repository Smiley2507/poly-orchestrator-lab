# ECS Fargate cluster running the same frontend/backend images as EKS (see
# eks.tf). Frontend is reached by the public ALB (alb.tf); the frontend also
# talks to the backend internally via ECS Service Connect (Cloud Map), which
# is the mechanism the lab asks for explicitly, even though normal browser
# traffic reaches the backend directly through the ALB's /api/* rule.

resource "aws_service_discovery_http_namespace" "ecs" {
  name        = "${local.name_prefix}.local"
  description = "Cloud Map namespace for ECS Service Connect"
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.ecs.arn
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

# Reuses the account's existing ECS task execution role rather than creating
# a new one - this lab account already has the standard one.
data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${local.name_prefix}-frontend"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}-backend"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${module.ecr_backend.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8000, protocol = "tcp", name = "backend" }
      ]
      environment = [
        { name = "DATABASE_HOST", value = aws_db_instance.this.address },
        { name = "DATABASE_PORT", value = tostring(aws_db_instance.this.port) },
        { name = "DATABASE_NAME", value = var.db_name },
        { name = "DATABASE_USER", value = var.db_username },
        { name = "DATABASE_PASSWORD", value = var.db_password },
        { name = "REDIS_HOST", value = aws_elasticache_cluster.this.cache_nodes[0].address },
        { name = "REDIS_PORT", value = tostring(aws_elasticache_cluster.this.port) },
        { name = "CORS_ORIGINS", value = "*" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${module.ecr_frontend.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 3000, protocol = "tcp", name = "frontend" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  # Registers "backend:8000" as a Cloud Map name any Service-Connect-enabled
  # task in this namespace (the frontend service) can reach directly.
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.ecs.arn

    service {
      port_name      = "backend"
      discovery_name = "backend"

      client_alias {
        port     = 8000
        dns_name = "backend"
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener_rule.api]

  tags = local.common_tags
}

resource "aws_ecs_service" "frontend" {
  name            = "${local.name_prefix}-frontend-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  # Enabled (with no advertised service of its own) so this task gets the
  # Service Connect proxy needed to resolve/reach "backend:8000".
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.ecs.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.http]

  tags = local.common_tags
}
