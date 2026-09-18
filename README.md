# Poly-Orchestrator — ShopNow on ECS and EKS

ShopNow is a three-tier e-commerce app (Frontend, Backend API, PostgreSQL, Redis) deployed twice on AWS, once on **ECS Fargate** and once on **EKS**, to compare the two orchestrators side by side. Both deployments run the same container images and share the same RDS and ElastiCache instances — only the orchestration layer differs.

> **Live demo URLs** (ephemeral, change on every redeploy)
> - ECS: `http://poly-orchestrator-alb-2078397140.eu-west-1.elb.amazonaws.com/`
> - EKS: `http://k8s-shopnow-e8672dfd39-59190178.eu-west-1.elb.amazonaws.com/`
>
> ```bash
> terraform -chdir=terraform output -raw alb_dns_name
> kubectl get ingress -n shopnow shopnow-ingress-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
> ```

## Local Development

The frontend and backend are containerized with Docker. `docker-compose.yml` runs the full stack locally: frontend, backend, PostgreSQL, Redis.

```bash
docker compose up --build
```

![Local application](docs/screenshots/docker-compose.png)

## Infrastructure

Terraform provisions the shared foundation both orchestrators run on:

* VPC, public/private subnets, NAT gateway
* Security groups
* ECR repositories (frontend, backend)
* Application Load Balancer
* RDS PostgreSQL
* ElastiCache Redis

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

![Terraform apply](docs/screenshots/terraform.png)

Frontend and backend images are built once and pushed to ECR, then reused by both the ECS and EKS deployments below.

```text
poly-orchestrator-frontend
poly-orchestrator-backend
```

![ECR repositories](docs/screenshots/ecr.png)

## ECS (Fargate)

### Architecture

![ECS architecture](docs/ecs-architecture-diagram.png)

The frontend and backend each run as an ECS Fargate service in private subnets. A public Application Load Balancer routes `/*` to the frontend and `/api/*` to the backend. Internally, the frontend can also reach the backend by name (`backend:8000`) over ECS Service Connect, which is backed by Cloud Map.

### What we implemented

* ECS cluster with two services (frontend, backend), two tasks each
* ALB with path-based routing to both services
* Service Connect for internal service discovery
* Backend connects privately to RDS and ElastiCache

### How it was implemented

Cluster, task definitions, and services are all defined in `terraform/ecs.tf` — nothing is created manually. `terraform apply` provisions the cluster, registers both task definitions against the ECR images, and creates both services with Service Connect enabled. The ALB target groups and the `/api/*` listener rule live in `terraform/alb.tf`.

```bash
aws ecs describe-services --cluster poly-orchestrator-cluster \
  --services poly-orchestrator-backend-service poly-orchestrator-frontend-service
```

![ECS services](docs/screenshots/ecs-services.png)

![ALB target health](docs/screenshots/target-health.png)

![Application running via ECS](docs/screenshots/application.png)

## EKS

### Architecture

![EKS architecture](docs/screenshots/eks-architecture-diagram.png)

The frontend and backend each run as a Kubernetes Deployment on a managed EC2 node group. A `Service` gives each one a stable internal DNS name via CoreDNS. The AWS Load Balancer Controller watches an `Ingress` and provisions a public ALB with the same `/*` and `/api/*` routing as the ECS side.

### What we implemented

* EKS cluster with a managed node group (2× t3.medium)
* Frontend and backend Deployments, two pods each
* ClusterIP Services for internal DNS-based discovery
* AWS Load Balancer Controller + Ingress for external routing
* Backend connects to the same RDS and ElastiCache instances as ECS

### How it was implemented

The cluster, node group, and the IAM role for the AWS Load Balancer Controller are defined in `terraform/eks.tf`. Once the cluster is up, the controller is installed with Helm and the manifests in `k8s/` are applied directly with `kubectl`.

```bash
aws eks update-kubeconfig --name poly-orchestrator-eks --region eu-west-1
helm install aws-load-balancer-controller <chart> -n kube-system \
  --set clusterName=poly-orchestrator-eks --set region=eu-west-1

kubectl apply -f k8s/
```

Service discovery needs no extra setup — any pod can already reach the backend by its Service name:

```bash
kubectl exec -n shopnow deploy/frontend -- wget -qO- http://backend:8000/health
```

The Ingress is split into two resources sharing one ALB (`alb.ingress.kubernetes.io/group.name`), because the frontend and backend need different health-check paths and that setting applies per Ingress, not per rule.

![EKS workloads](docs/screenshots/eks-workloads.png)

![EKS target group health](docs/screenshots/eks-target-health.png)

![Application running via EKS](docs/screenshots/eks-application.png)

## Resiliency

Both orchestrators were tested by manually killing a running backend instance.

**ECS**: stopped a task directly (`aws ecs stop-task`). The service scheduler started a replacement within seconds and `runningCount` went back to 2.

**EKS**: deleted a running pod directly (`kubectl delete pod`). The Deployment's ReplicaSet created a replacement, ready again in about 20 seconds.

The app kept serving traffic throughout on both, since each orchestrator always kept at least one healthy replica behind its load balancer.

## Comparison

| | ECS (Fargate) | EKS |
|---|---|---|
| Setup | Cluster, task defs and services are plain Terraform resources | Cluster, node group, IRSA role, and a separate Ingress controller to install |
| Time to a running app | A few minutes — control plane is instant | 10-12 minutes — the EKS control plane alone takes 8-10 minutes to come up |
| Compute | Serverless per task, no nodes to manage | EC2 node group you size and patch yourself |
| Service discovery | Cloud Map / Service Connect, configured per service | Built in — any Service gets a DNS name from CoreDNS |
| Load balancing | Native ALB integration on the service | Needs the AWS Load Balancer Controller to turn Ingress objects into ALBs |
| Scaling | ECS desired count / Application Auto Scaling | Deployment replicas / Horizontal Pod Autoscaler |
| Self-healing | Scheduler replaces a stopped task in seconds | ReplicaSet replaces a deleted pod in seconds |
| Portability | AWS-specific | Standard Kubernetes API, portable to other clusters |
| Ops overhead | Lower — AWS manages the control plane and compute | Higher — cluster upgrades, node patching, and add-ons are on you |

For ShopNow, ECS got a working deployment up faster with fewer moving parts. EKS took longer to stand up and needs more components to operate, but gives standard Kubernetes portability if that becomes worth the extra overhead.
