# A single small RDS PostgreSQL instance, native resources rather than a module:
# for one instance the module's surface area (~40 variables covering read
# replicas, monitoring roles, blue/green, etc.) would hide more than it clarifies.
#
# Kept deliberately simple for a lab: single-AZ, minimal storage, no Performance
# Insights, final snapshot skipped on destroy.

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-rds"

  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az = false

  backup_retention_period = 1
  apply_immediately       = true

  # Lab environment: prioritize simplicity and cost over production safeguards.
  skip_final_snapshot = true
  deletion_protection = false

  performance_insights_enabled = false

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds" })
}
