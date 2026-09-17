# Security model summary:
#
#   Internet --80--> [ALB SG] --80--> [ECS SG] <--Service Connect--> [ECS SG]
#                                         │                              │
#                                       5432                           6379
#                                         ▼                              ▼
#                                     [RDS SG]                     [Redis SG]
#
# Every security group only accepts traffic from the specific security group in
# front of it in the chain - nothing but the ALB is reachable from 0.0.0.0/0, and
# RDS/ElastiCache are never reachable from anywhere except the ECS tasks.

# --- ALB security group ---
# Public entry point: accepts HTTP from the internet, forwards to ECS tasks only.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Internet-facing ALB - allows inbound HTTP from anywhere"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "To ECS tasks (and anywhere required for health checks)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

# --- ECS security group ---
# Shared by the frontend and backend services. The frontend accepts traffic only
# from the ALB; both services can reach each other over Service Connect, which
# uses a range of ports assigned per task, so intra-SG traffic is allowed rather
# than a single fixed port.
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "ECS Fargate tasks (frontend + backend) - no direct internet ingress"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Frontend container port, from the ALB only"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Backend container port, from the ALB only"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service Connect / inter-service traffic between frontend and backend tasks"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Outbound to ECR, RDS, ElastiCache and other AWS endpoints via the NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ecs-sg" })
}

# --- RDS security group ---
# Only reachable from the ECS tasks and EKS worker nodes, never from the
# internet. Ingress rules are separate aws_security_group_rule resources
# (rather than inline) so the EKS rule added in eks.tf doesn't fight with an
# inline block for ownership of this group's rule set.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS PostgreSQL - only reachable from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-sg" })
}

resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "PostgreSQL from ECS tasks"
}

# --- ElastiCache security group ---
# Only reachable from the ECS tasks and EKS worker nodes, never from the
# internet.
resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "ElastiCache Redis - only reachable from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-redis-sg" })
}

resource "aws_security_group_rule" "ecs_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "Redis from ECS tasks"
}
