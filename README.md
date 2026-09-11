# Poly-Orchestrator — AWS ECS Deployment

A containerized e-commerce application deployed on **Amazon ECS using AWS Fargate**.

The project demonstrates how a multi-container application running locally with Docker Compose can be deployed to AWS using managed container, networking, database, and caching services.

**Current deployment:** Amazon ECS / AWS Fargate
**AWS Region:** `eu-west-1`
**Environment:** Lab / Demonstration

---

## Table of Contents

* [Project Overview](#project-overview)
* [Architecture](#architecture)
* [Technology Stack](#technology-stack)
* [AWS Infrastructure](#aws-infrastructure)
* [ECS Deployment](#ecs-deployment)
* [Traffic and Service Communication](#traffic-and-service-communication)
* [Deployment Process](#deployment-process)
* [Application Verification](#application-verification)
* [Troubleshooting](#troubleshooting)
* [Lessons Learned](#lessons-learned)
* [Project Structure](#project-structure)
* [Next Step: EKS](#next-step-eks)

---

# Project Overview

**Poly-Orchestrator** is a small e-commerce application consisting of:

* React/Vite frontend
* FastAPI backend
* PostgreSQL database
* Redis cache

The application was first developed and tested locally using Docker Compose.

For the AWS deployment, the application containers run on ECS Fargate, while PostgreSQL and Redis are provided by managed AWS services.

| Local Component   | AWS Deployment            |
| ----------------- | ------------------------- |
| Frontend          | ECS Fargate               |
| Backend           | ECS Fargate               |
| PostgreSQL        | Amazon RDS                |
| Redis             | Amazon ElastiCache        |
| Docker images     | Amazon ECR                |
| External traffic  | Application Load Balancer |
| Service discovery | ECS Service Connect       |

---

# Architecture

![Poly-Orchestrator AWS ECS Architecture](docs/ecs-architecture-diagram.png)

The application is deployed inside an AWS VPC using public and private subnets. The **Application Load Balancer** provides the public entry point and routes `/api/*` requests to the backend ECS service while sending other requests to the frontend service.

The frontend and backend run as separate ECS Fargate services. **ECS Service Connect** provides internal service-to-service communication, while the backend connects privately to **Amazon RDS PostgreSQL** and **Amazon ElastiCache Redis**. The frontend does not directly access either data service.

### Application Screenshot

![ShopNow Application](docs/screenshots/application.png)

---

# Technology Stack

## Application

| Component           | Technology                |
| ------------------- | ------------------------- |
| Frontend            | React + Vite + TypeScript |
| Backend             | FastAPI                   |
| Database            | PostgreSQL                |
| Cache               | Redis                     |
| Containers          | Docker                    |
| Local orchestration | Docker Compose            |

## AWS

| Service                   | Purpose                                      |
| ------------------------- | -------------------------------------------- |
| Amazon ECS                | Container orchestration                      |
| AWS Fargate               | Container compute                            |
| Amazon ECR                | Container image registry                     |
| Application Load Balancer | External traffic routing                     |
| Amazon RDS                | Managed PostgreSQL                           |
| Amazon ElastiCache        | Managed Redis                                |
| Amazon VPC                | Network isolation                            |
| CloudWatch                | Container logging                            |
| ECS Service Connect       | Service discovery and internal communication |

---

# AWS Infrastructure

The AWS infrastructure is provisioned using **Terraform**.

The main resources are:

* VPC
* Public and private subnets
* Internet Gateway
* NAT Gateway
* Route tables
* Security groups
* ECR repositories
* Application Load Balancer
* ALB target groups
* Amazon RDS PostgreSQL
* Amazon ElastiCache Redis

### Network Layout

```text
VPC: 10.0.0.0/16

Public Subnets
├── 10.0.1.0/24
└── 10.0.2.0/24
        │
        └── Application Load Balancer

Private Subnets
├── 10.0.11.0/24
└── 10.0.12.0/24
        │
        ├── ECS Frontend
        ├── ECS Backend
        ├── RDS PostgreSQL
        └── ElastiCache Redis
```

The ALB is placed in the public subnets, while ECS tasks and data services remain in the private subnets.

### Terraform Structure

```text
terraform/
├── alb.tf
├── ecr.tf
├── elasticache.tf
├── rds.tf
├── security-groups.tf
├── vpc.tf
├── variables.tf
├── outputs.tf
├── provider.tf
├── versions.tf
└── terraform.tfvars.example
```

---

# ECS Deployment

The application runs in the ECS cluster:

```text
poly-orchestrator-cluster
```

Two ECS services are deployed:

```text
poly-orchestrator-frontend-service
poly-orchestrator-backend-service
```

Both services run on **AWS Fargate** with a desired count of two tasks.

### Frontend Service

```text
Container: frontend
Port: 3000
Desired tasks: 2
```

The frontend serves the compiled React application using a lightweight Node.js server.

### Backend Service

```text
Container: backend
Port: 8000
Desired tasks: 2
```

The FastAPI backend exposes:

```text
GET /health
GET /api/products
GET /api/products/{id}
```

### Health Checks

The frontend is checked using:

```text
GET /
```

The backend is checked using:

```text
GET /health
```

These checks allow ECS and the ALB to determine whether tasks are healthy and ready to receive traffic.

---

# Traffic and Service Communication

The Application Load Balancer provides the single public entry point.

```text
HTTP :80
```

Path-based routing is configured as:

```text
/api/*  → Backend ECS :8000
/*      → Frontend ECS :3000
```

The frontend uses the relative API path:

```text
/api
```

This allows browser requests to use the same ALB endpoint as the frontend.

ECS Service Connect provides internal communication between the frontend and backend:

```text
Frontend ECS
     │
     │ Service Connect
     ▼
Backend ECS
```

The backend then accesses the data services privately:

```text
Backend ECS → RDS PostgreSQL :5432
Backend ECS → ElastiCache Redis :6379
```

The frontend does **not** connect directly to RDS or Redis.

### ALB Listener

![ALB Listener Rules](docs/screenshots/alb-listener.png)

### Service Connect

![ECS Service Connect](docs/screenshots/service-connect.png)

---

# Deployment Process

## 1. Test Locally

The application was first verified using Docker Compose:

```bash
docker compose up --build
```

This starts:

```text
Frontend
Backend
PostgreSQL
Redis
```
---

## 2. Provision AWS Infrastructure

Terraform provisions the required AWS infrastructure:

```bash
cd terraform

terraform init
terraform plan
terraform apply
```
---

## 3. Build and Push Images

The application images are built locally and pushed to Amazon ECR.

```bash
docker build -t poly-orchestrator-backend ./backend
docker build -t poly-orchestrator-frontend ./frontend
```

Example image tags:

```text
poly-orchestrator-backend:v1
poly-orchestrator-frontend:v1
poly-orchestrator-frontend:v2
```

![ECR Images](docs/screenshots/ecr.png)

---

## 4. Deploy ECS Services

Separate ECS task definitions were created for the frontend and backend.

The task definitions specify:

* Container image
* CPU and memory
* Port mappings
* Environment variables
* Health checks
* CloudWatch logging
* IAM roles

The task definitions are used by the ECS services.

![ECS Services](docs/screenshots/ecs-services.png)

---

## 5. Configure Load Balancing

The ALB uses two target groups:

| Service  | Target Group                       | Port | Health Check |
| -------- | ---------------------------------- | ---: | ------------ |
| Frontend | `poly-orchestrator-frontend-v2-tg` | 3000 | `/`          |
| Backend  | `poly-orchestrator-backend-tg`     | 8000 | `/health`    |

---

# Application Verification

After deployment, the application was tested through the public ALB endpoint.

### Frontend

```text
http://<ALB-DNS>/
```

### Backend API

```text
http://<ALB-DNS>/api/products
```

### Target Health

Both frontend and backend target groups were checked to confirm that ECS tasks were registered and healthy.

![Healthy Target Groups](docs/screenshots/target-health.png)

![Running Application](docs/screenshots/application.png)

---

# Troubleshooting

The deployment involved several issues that demonstrated important ECS and ALB concepts.

## Frontend Nginx — 502 Bad Gateway

The initial frontend image used Nginx to proxy `/api` requests to the backend.

Although Service Connect was working, Nginx returned `502 Bad Gateway`.

The frontend was simplified to serve the React application directly, while the ALB became responsible for API routing:

```text
/api/* → Backend
/*     → Frontend
```

---

## Frontend Target Health Timeout

After moving the frontend to port `3000`, the ALB could not reach the frontend tasks.

The missing rule was:

```text
ALB SG → ECS SG → TCP 3000
```

After adding the rule, the frontend targets became healthy.

---

## Backend Target Health Timeout

The backend tasks were running, but the ALB reported that port `8000` was unhealthy.

The missing rule was:

```text
ALB SG → ECS SG → TCP 8000
```

After adding the rule and deploying new backend tasks, the targets became healthy.

---

## Backend Target Group Had No Targets

The backend target group initially had no registered targets because the ECS backend service was not associated with the target group.

The service was updated to connect:

```text
backend:8000
        ↓
poly-orchestrator-backend-tg
```

ECS then registered the backend tasks.

---

# Lessons Learned

### ALB 503 does not always mean the application is broken

A `503 Service Unavailable` can occur when the ALB has no healthy targets.

Checking target-group health is therefore an important troubleshooting step.

### ECS and ALB configuration must align

The following components must work together:

```text
Container port
      ↓
ECS port mapping
      ↓
ECS service
      ↓
Target group
      ↓
ALB listener
      ↓
Security group
```

A mismatch can prevent traffic from reaching the application.

### Service Connect and ALB have different roles

The ALB handles external browser traffic and path-based routing.

Service Connect provides internal ECS service discovery and communication.

### Managed services simplify the deployment

RDS and ElastiCache replace the local PostgreSQL and Redis containers, allowing ECS to focus on the application containers.

---

# Project Structure

```text
poly-orchestrator-lab/
│
├── backend/
│   ├── app/
│   ├── Dockerfile
│   └── requirements.txt
│
├── frontend/
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── ...
│
├── terraform/
│   ├── alb.tf
│   ├── ecr.tf
│   ├── elasticache.tf
│   ├── rds.tf
│   ├── security-groups.tf
│   ├── vpc.tf
│   └── ...
│
├── docker-compose.yml
└── README.md
```

---

# Next Step: EKS

The next phase is to deploy the same application using **Amazon EKS**.

The application architecture will remain largely the same:

```text
Frontend
Backend
RDS PostgreSQL
ElastiCache Redis
```

The main difference will be the orchestration platform.

### ECS

```text
AWS
└── ECS
    └── Fargate
        ├── Frontend
        └── Backend
```

### EKS

```text
AWS
└── EKS
    └── Kubernetes
        ├── Frontend Deployment
        └── Backend Deployment
```

This will allow the project to compare ECS/Fargate with Kubernetes running on EKS using the same application.
