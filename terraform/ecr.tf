# Private ECR repositories only - no images are built or pushed by Terraform.
# The next phase pushes images here (build -> tag -> authenticate -> push) before
# ECS task definitions can reference them.

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

module "ecr_frontend" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name                 = "${var.project_name}-frontend"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true

  create_lifecycle_policy     = true
  repository_lifecycle_policy = local.ecr_lifecycle_policy

  # Repository must survive `terraform destroy` accidents on a shared lab account
  # only if it still has images; leave default force_delete = false.

  tags = local.common_tags
}

module "ecr_backend" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name                 = "${var.project_name}-backend"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true

  create_lifecycle_policy     = true
  repository_lifecycle_policy = local.ecr_lifecycle_policy

  tags = local.common_tags
}
