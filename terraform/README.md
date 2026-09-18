# ShopNow — AWS Infrastructure (Terraform)

Provisions the shared network and data layer plus both orchestrators: VPC, ALB, ECR, RDS, ElastiCache, security groups, the ECS cluster/services (`ecs.tf`), and the EKS cluster/node group (`eks.tf`). See the root `README.md` for the full deployment walkthrough and the ECS vs EKS comparison. The Kubernetes manifests in `../k8s/` are applied separately with `kubectl`, same as the container images are pushed separately with `docker push`.

## What this creates

| Area | Resource(s) | Module / native |
|---|---|---|
| Networking | VPC, 2 public + 2 private subnets, IGW, 1 NAT Gateway | `terraform-aws-modules/vpc/aws` |
| Container registry | 2 private ECR repos (frontend, backend) | `terraform-aws-modules/ecr/aws` |
| Load balancing | Internet-facing ALB, frontend + backend target groups, path-based routing | native |
| Database | RDS PostgreSQL, single-AZ, private subnets only | native |
| Cache | ElastiCache Redis, single node, private subnets only | native |
| Security | Security groups for ALB, ECS, EKS nodes, RDS, Redis | native |
| ECS | Cluster, task definitions, services with Service Connect | native |
| EKS | Cluster, managed node group, IRSA role for the LB controller | `terraform-aws-modules/eks/aws`, `.../iam` |

## VPC design

* CIDR `10.0.0.0/16` across 2 AZs (`eu-west-1a`, `eu-west-1b`)
* Public subnets (`10.0.1.0/24`, `10.0.2.0/24`): ALB and NAT Gateway
* Private subnets (`10.0.11.0/24`, `10.0.12.0/24`): ECS tasks, EKS nodes, RDS, ElastiCache
* One NAT Gateway rather than one per AZ, to keep cost down for a lab environment
* DNS support/hostnames enabled — required by ECS Service Connect and EKS

## Security groups

```text
Internet --80--> [ALB SG] --3000/8000--> [ECS SG] --5432/6379--> [RDS SG] / [Redis SG]
                            \-3000/8000-> [EKS node SG] --5432/6379-^
```

Only the ALB is open to `0.0.0.0/0`. ECS tasks and EKS nodes can both reach RDS and ElastiCache; nothing else can.

## Database password and state

`db_password` ends up in `terraform.tfstate` in plaintext, as it does for any Terraform-managed RDS password. State is local and gitignored — never commit it. Beyond a lab, prefer a remote backend with encryption and/or `manage_master_user_password = true` so RDS manages the secret itself.

## Outputs

| Output | Used for |
|---|---|
| `vpc_id`, `public_subnet_ids`, `private_subnet_ids` | Networking config for ECS/EKS |
| `frontend_ecr_repository_url`, `backend_ecr_repository_url` | `docker push` targets |
| `alb_dns_name`, `frontend_target_group_arn`, `backend_target_group_arn` | ECS load balancing |
| `rds_endpoint`, `rds_port`, `rds_database_name` | Backend DB env vars |
| `redis_endpoint`, `redis_port` | Backend cache env vars |
| `ecs_cluster_name` | ECS CLI commands |
| `eks_cluster_name`, `eks_cluster_endpoint` | `aws eks update-kubeconfig` |
| `eks_lb_controller_role_arn` | Helm install of the AWS Load Balancer Controller |

The database password is never output.

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then edit db_password locally

aws sts get-caller-identity --profile sandbox-user   # confirm the account first

terraform init
terraform plan
terraform apply
```

## Teardown

```bash
kubectl delete -f ../k8s/     # remove the Ingress first, so its ALB is cleaned up
terraform destroy
```

This removes the VPC, ALB, ECS cluster/services, EKS cluster/node group, RDS instance, and ElastiCache node. It does not delete ECR images — clean those up separately if needed.
