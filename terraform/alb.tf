# Internet-facing ALB. Only the frontend target group is created here: the
# frontend is the only service meant to be reachable from outside the VPC. The
# backend is reached by the frontend over ECS Service Connect, configured
# manually in the next phase.
resource "aws_lb" "frontend" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })
}

# target_type = "ip" is required for ECS Fargate + awsvpc networking: tasks are
# registered by ENI IP address, not by EC2 instance ID.
#
# Port 3000 matches the frontend container (frontend/Dockerfile runs
# `serve -l 3000`) - the health check path is "/" since the frontend is a
# plain static file server with no dedicated health endpoint.
resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-frontend-tg" })
}

# Backend target group - matches backend/Dockerfile (uvicorn on :8000).
# Exposed on the same public ALB via a path rule for convenience (curling
# /api/* directly during the demo); the frontend itself doesn't depend on
# this path, since it calls "backend:8000" internally over ECS Service
# Connect (Cloud Map) - see ecs.tf.
resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-backend-tg" })
}

# HTTP only for this lab - the objective is container orchestration, not TLS
# termination. HTTPS/ACM can be added later without changing this foundation.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = local.common_tags
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = local.common_tags
}
