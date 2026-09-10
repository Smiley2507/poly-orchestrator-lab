# --- Networking ---

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT Gateway)"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ECS tasks, RDS, ElastiCache)"
  value       = module.vpc.private_subnets
}

output "ecs_security_group_id" {
  description = "Security group ID to attach to ECS tasks in the next phase"
  value       = aws_security_group.ecs.id
}

# --- ECR ---

output "frontend_ecr_repository_url" {
  description = "ECR repository URL for the frontend image"
  value       = module.ecr_frontend.repository_url
}

output "backend_ecr_repository_url" {
  description = "ECR repository URL for the backend image"
  value       = module.ecr_backend.repository_url
}

# --- ALB ---

output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.frontend.dns_name
}

output "frontend_target_group_arn" {
  description = "Target group ARN the ECS frontend service should register with"
  value       = aws_lb_target_group.frontend.arn
}

output "alb_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# --- RDS ---

output "rds_endpoint" {
  description = "RDS PostgreSQL connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.this.port
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name"
  value       = aws_db_instance.this.db_name
}

# --- ElastiCache ---

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint address"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.this.port
}
