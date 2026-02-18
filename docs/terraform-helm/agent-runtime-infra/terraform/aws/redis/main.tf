terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

#############################################
# Variables
#############################################

variable "name" {
  description = "Unique name/identifier for the resources"
  type        = string
}

variable "user_id" {
  description = "User Id for tagging the resource"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy the ElastiCache cluster in"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC for security group rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ElastiCache subnet group"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.medium"
}

variable "ha" {
  description = "Enable Redis cluster mode"
  type        = bool
  default     = false
}

variable "replicas_per_node_group" {
  description = "Number of replicas per node group"
  type        = number
  default     = 2
}

variable "num_node_groups" {
  description = "Number of node groups"
  type        = number
  default     = 1
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "parameter_group_name" {
  description = "ElastiCache parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

#############################################
# Provider
#############################################

provider "aws" {
  region = var.region
}

#############################################
# Password Generation
#############################################

resource "random_password" "redis_password" {
  length           = 20
  special          = false
  override_special = "_"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
}

#############################################
# SSM Parameter Store for Credentials
#############################################

resource "aws_ssm_parameter" "redis_password" {
  name  = "/agent-runtime/${var.name}/redis/password"
  type  = "SecureString"
  value = random_password.redis_password.result

  tags = {
    Name   = "${var.name}-redis-password"
    UserID = var.user_id
  }
}

#############################################
# Security Group for ElastiCache
#############################################

resource "aws_security_group" "redis_sg" {
  name        = "${var.name}-redis-sg"
  description = "Security Group for Redis ElastiCache"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis access"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "${var.name}-redis-sg"
    UserID = var.user_id
  }
}

#############################################
# ElastiCache Subnet Group
#############################################

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "redis-${var.name}"
  description = "Subnet group for Redis ElastiCache"
  subnet_ids  = var.subnet_ids

  tags = {
    Name   = "redis-${var.name}"
    UserID = var.user_id
  }
}

#############################################
# ElastiCache Redis Replication Group
#############################################

resource "aws_elasticache_replication_group" "redis" {
  description                = "redis-${var.name}"
  replication_group_id       = "redis-${var.name}"

  auth_token                 = random_password.redis_password.result
  automatic_failover_enabled = var.ha
  multi_az_enabled           = var.ha

  node_type                  = var.node_type
  parameter_group_name       = var.parameter_group_name
  port                       = var.port

  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]

  replicas_per_node_group    = var.ha ? var.replicas_per_node_group : 0
  num_node_groups            = var.num_node_groups

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  engine                     = "redis"
  engine_version             = "7.0"
  apply_immediately          = true

  snapshot_retention_limit   = var.snapshot_retention_limit

  tags = {
    Name   = "redis-${var.name}"
    UserID = var.user_id
  }
}

#############################################
# Outputs
#############################################

output "host" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = tostring(var.port)
}

output "password" {
  description = "Redis auth token"
  value       = random_password.redis_password.result
  sensitive   = true
}

output "replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

output "configuration_endpoint" {
  description = "Redis configuration endpoint (for cluster mode)"
  value       = try(aws_elasticache_replication_group.redis.configuration_endpoint_address, "")
}
