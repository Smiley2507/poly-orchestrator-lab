# EKS cluster running the same frontend/backend images as ECS (see ecs.tf),
# for a side-by-side orchestrator comparison. Worker nodes live in the same
# private subnets as the ECS tasks/RDS/ElastiCache, reusing the existing NAT
# Gateway for egress.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.eks_cluster_name
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Needed for the AWS Load Balancer Controller's IAM role (IRSA below).
  enable_irsa = true

  # Without this, the IAM identity that ran `terraform apply` has no
  # Kubernetes RBAC access at all (v20 module default) - kubectl/helm need it.
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = local.common_tags
}

# IAM role for the AWS Load Balancer Controller's Kubernetes service account
# (IRSA) - the submodule ships the controller's IAM policy, so it doesn't
# need to be hand-copied here.
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name_prefix}-eks-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# The backend/Redis/Postgres security groups only allow the ECS task security
# group by default (security-groups.tf) - open them to EKS worker nodes too,
# since both orchestrators share the same RDS/ElastiCache instances.
resource "aws_security_group_rule" "eks_nodes_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = module.eks.node_security_group_id
  description              = "PostgreSQL from EKS worker nodes"
}

resource "aws_security_group_rule" "eks_nodes_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = module.eks.node_security_group_id
  description              = "Redis from EKS worker nodes"
}
