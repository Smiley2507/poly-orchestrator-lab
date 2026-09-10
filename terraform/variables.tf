variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to authenticate with (never a hardcoded key/secret)"
  type        = string
  default     = "sandbox-user"
}

variable "project_name" {
  description = "Short project name used as a prefix for resource names and tags"
  type        = string
  default     = "poly-orchestrator"
}

variable "environment" {
  description = "Environment name, used in tags"
  type        = string
  default     = "lab"
}

# --- Networking ---

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across (exactly 2 for this lab)"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ) - ALB and NAT Gateway live here"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ) - ECS tasks, RDS and ElastiCache live here"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# --- RDS PostgreSQL ---

variable "db_name" {
  description = "Initial database name created on the RDS instance"
  type        = string
  default     = "shopnow"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "shopnow"
}

variable "db_password" {
  description = "Master password for the RDS instance. Supply via terraform.tfvars (gitignored) or TF_VAR_db_password - never commit it."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class - kept small deliberately for a lab environment"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.15"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS, in GiB"
  type        = number
  default     = 20
}

# --- ElastiCache Redis ---

variable "redis_node_type" {
  description = "ElastiCache node type - kept small deliberately for a lab environment"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}
