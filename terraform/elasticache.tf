# A single small ElastiCache Redis node, native resources rather than a module
# (same reasoning as RDS: one cache cluster is clearer as plain resources than
# wrapped behind a general-purpose module).
#
# A single cluster node (no replication group) is enough for a lab cache - if a
# task restarts and the cache is briefly empty, the backend's existing fail-soft
# behavior falls back to PostgreSQL.

resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = local.common_tags
}

resource "aws_elasticache_cluster" "this" {
  cluster_id = "${local.name_prefix}-redis"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type

  num_cache_nodes = 1
  port            = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  apply_immediately = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-redis" })
}
