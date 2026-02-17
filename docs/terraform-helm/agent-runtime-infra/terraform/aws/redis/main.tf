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

provider "aws" {
  region = "{{ $sys.deploymentCell.region }}"
}

#############################################
# Variables with Omnistrate System Parameters
#############################################

variable "name" {
  type    = string
  default = "{{ $sys.id }}"
}

variable "region" {
  type    = string
  default = "{{ $sys.deploymentCell.region }}"
}

variable "vpc_id" {
  type    = string
  default = "{{ $sys.deploymentCell.cloudProviderNetworkID }}"
}

variable "vpc_cidr" {
  type    = string
  default = "{{ $sys.deploymentCell.cidrRange }}"
}

variable "subnet_ids" {
  type = list(string)
  default = [
    "{{ $sys.deploymentCell.privateSubnetIDs[0].id }}",
    "{{ $sys.deploymentCell.privateSubnetIDs[1].id }}",
    "{{ $sys.deploymentCell.privateSubnetIDs[2].id }}"
  ]
}

# User and Org tags from Omnistrate tenant parameters
variable "user_id" {
  type        = string
  description = "User ID from Omnistrate"
  default     = "{{ $sys.tenant.userID }}"
}

variable "user_email" {
  type        = string
  description = "User email from Omnistrate"
  default     = "{{ $sys.tenant.email }}"
}

variable "org_id" {
  type        = string
  description = "Organization ID from Omnistrate"
  default     = "{{ $sys.tenant.orgId }}"
}

variable "org_name" {
  type        = string
  description = "Organization name from Omnistrate"
  default     = "{{ $sys.tenant.orgName }}"
}

# Redis configuration
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
  type    = number
  default = 6379
}

variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}

variable "snapshot_retention_limit" {
  type    = number
  default = 7
}

#############################################
# Common Tags with User and Org Information
#############################################

locals {
  common_tags = {
    ManagedBy   = "Omnistrate"
    InstanceID  = var.name
    UserID      = var.user_id
    UserEmail   = var.user_email
    OrgID       = var.org_id
    OrgName     = var.org_name
    Environment = "{{ $sys.deploymentCell.environmentType }}"
    ServiceID   = "{{ $sys.deployment.serviceID }}"
    PlanID      = "{{ $sys.deployment.planID }}"
    Region      = var.region
  }
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
  name  = "/omnistrate/${var.name}/redis/password"
  type  = "SecureString"
  value = random_password.redis_password.result

  tags = local.common_tags
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

  tags = merge(local.common_tags, {
    Name = "${var.name}-redis-sg"
  })
}

#############################################
# ElastiCache Subnet Group
#############################################

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "redis-${var.name}"
  description = "Subnet group for Redis ElastiCache"
  subnet_ids  = var.subnet_ids

  tags = local.common_tags
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

  tags = merge(local.common_tags, {
    Name = "redis-${var.name}"
  })
}

#############################################
# Outputs - Exposed to Omnistrate
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
