# Poly-Orchestrator — AWS ECS Deployment

Poly-Orchestrator is a containerized three-tier e-commerce application deployed on **Amazon ECS using AWS Fargate**.

The project demonstrates how a multi-container application can be moved from a local Docker Compose environment to AWS using managed services such as **Amazon ECS, Amazon ECR, Application Load Balancer, Amazon RDS, ElastiCache Redis, and Terraform**.

The deployment uses a public Application Load Balancer for external traffic, ECS Service Connect for internal service communication, and private networking for the application and data services. The goal of the lab is to practice container deployment, AWS networking, service discovery, load balancing, and infrastructure provisioning with Terraform.

## Architecture

![Poly-Orchestrator AWS Architecture](docs/ecs-architecture-diagram.png)

The application is deployed inside an AWS VPC using ECS Fargate. An internet-facing Application Load Balancer provides the public entry point and routes frontend and API traffic to their respective ECS services.

The frontend communicates with the backend through ECS Service Connect. The backend privately accesses Amazon RDS PostgreSQL for persistent data and Amazon ElastiCache Redis for caching. The ECS tasks and data services are deployed in private subnets, while the ALB is placed in public subnets.

## 1. Containerization & Local Testing

The frontend and backend were containerized using Docker, with Docker Compose used to run the complete application locally.

```bash
docker compose up --build
```

The local environment consists of:

```text
Frontend
Backend
PostgreSQL
Redis
```

![Local Application](docs/screenshots/docker-compose.png)

---

## 2. Infrastructure with Terraform

Terraform was used to provision the AWS infrastructure required by the application.

The infrastructure includes:

* VPC and subnets
* Internet Gateway and NAT Gateway
* Security groups
* ECR repositories
* Application Load Balancer
* RDS PostgreSQL
* ElastiCache Redis

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

![Terraform Apply](docs/screenshots/terraform.png)

---

## 3. Amazon ECR

The frontend and backend Docker images were pushed to separate Amazon ECR repositories.

```text
poly-orchestrator-frontend
poly-orchestrator-backend
```

Versioned image tags were used for deployment.

![ECR Repositories](docs/screenshots/ecr.png)

---

## 4. ECS Deployment

The application was deployed to an ECS cluster using AWS Fargate.

Two services were created:

```text
poly-orchestrator-frontend-service
poly-orchestrator-backend-service
```

Each service runs two tasks for basic redundancy.

The frontend listens on port `3000`, while the backend listens on port `8000`.

![ECS Services](docs/screenshots/ecs-services.png)

---

## 5. Load Balancing & Service Connect

The Application Load Balancer routes traffic based on the request path:

```text
/api/*  → Backend :8000
/*      → Frontend :3000
```

ECS Service Connect provides internal communication between the frontend and backend services.

The backend then connects privately to:

```text
RDS PostgreSQL :5432
ElastiCache Redis :6379
```

![ALB Listener Rules](docs/screenshots/alb-listener.png)

---

## 6. Final Validation

The deployed application was accessed through the ALB DNS name.

The following were verified:

* Frontend loads successfully
* Backend API responds through `/api/products`
* Frontend communicates with the backend
* Backend connects to PostgreSQL
* Redis caching works
* ALB target groups report healthy ECS tasks

![Healthy Target Groups](docs/screenshots/target-health.png)

![Running Application](docs/screenshots/application.png)

---

## 7. Troubleshooting

During deployment, several issues were encountered and resolved:

* Frontend Nginx returned `502 Bad Gateway`, so API routing was moved to the ALB.
* The frontend target group could not reach port `3000` because of a missing security-group rule.
* The backend target group could not reach port `8000` for the same reason.
* The backend target group initially had no targets because it was not attached to the ECS service.

These issues highlighted the importance of correctly aligning **ECS port mappings, target groups, ALB rules, health checks, and security groups**.

---

## 8. Lessons Learned

* ECS services, ALB target groups, and security groups must be configured consistently.
* An ALB `503` can indicate that there are no healthy targets rather than an application failure.
* Service Connect is useful for internal ECS service communication, while the ALB handles external traffic.
* Managed services such as RDS and ElastiCache reduce the infrastructure that must be managed inside ECS.
* ECS Fargate allows containers to run without managing the underlying servers.

---

## Project Structure

```text
poly-orchestrator-lab/
├── backend/
├── frontend/
├── terraform/
├── docs/
├── docker-compose.yml
└── README.md
```
---

## Next Step

The next phase of the project is to deploy the same application using **Amazon EKS** and compare the ECS/Fargate and Kubernetes approaches.
