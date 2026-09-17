locals {
  name_prefix      = var.project_name
  eks_cluster_name = "${var.project_name}-eks"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
