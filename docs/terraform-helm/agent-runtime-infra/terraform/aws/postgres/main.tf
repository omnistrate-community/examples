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
  description = "VPC ID to deploy the RDS instance in"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC for security group rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.medium"
}

variable "disk_size" {
  description = "Allocated storage in GB"
  type        = number
  default     = 50
}

variable "ha" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "postgres"
}

variable "storage_type" {
  description = "Storage type for the RDS instance"
  type        = string
  default     = "gp3"
}

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "max_allocated_storage" {
  description = "Specifies the value for Storage Autoscaling"
  type        = number
  default     = 500
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
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

resource "random_password" "postgres_password" {
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

resource "aws_ssm_parameter" "postgres_username" {
  name  = "/agent-runtime/${var.name}/postgres/username"
  type  = "SecureString"
  value = var.rds_username

  tags = {
    Name   = "${var.name}-postgres-username"
    UserID = var.user_id
  }
}

resource "aws_ssm_parameter" "postgres_password" {
  name  = "/agent-runtime/${var.name}/postgres/password"
  type  = "SecureString"
  value = random_password.postgres_password.result

  tags = {
    Name   = "${var.name}-postgres-password"
    UserID = var.user_id
  }
}

#############################################
# Security Group for RDS
#############################################

resource "aws_security_group" "postgres_sg" {
  name        = "${var.name}-postgres-sg"
  description = "Security Group for PostgreSQL RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
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
    Name   = "${var.name}-postgres-sg"
    UserID = var.user_id
  }
}

#############################################
# DB Subnet Group
#############################################

resource "aws_db_subnet_group" "postgres_subnet_group" {
  name        = "postgres-${var.name}"
  description = "Subnet group for PostgreSQL RDS"
  subnet_ids  = var.subnet_ids

  tags = {
    Name   = "postgres-${var.name}"
    UserID = var.user_id
  }
}

#############################################
# CloudWatch Log Groups
#############################################

resource "aws_cloudwatch_log_group" "postgres_logs" {
  for_each          = toset(["postgresql", "upgrade"])
  name              = "/aws/rds/instance/postgres-${var.name}/${each.value}"
  retention_in_days = 7

  tags = {
    Name   = "postgres-${var.name}-${each.value}"
    UserID = var.user_id
  }
}

#############################################
# RDS PostgreSQL Instance
#############################################

resource "aws_db_instance" "postgres" {
  identifier              = "postgres-${var.name}"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = var.instance_type
  allocated_storage       = var.disk_size
  storage_type            = var.storage_type
  storage_encrypted       = true

  db_name  = "agent_runtime"
  username = var.rds_username
  password = random_password.postgres_password.result
  port     = 5432

  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet_group.name
  multi_az               = var.ha
  publicly_accessible    = false
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  maintenance_window          = "Mon:00:00-Mon:03:00"
  copy_tags_to_snapshot       = true
  skip_final_snapshot         = true

  backup_retention_period         = var.backup_retention_period
  backup_window                   = "03:00-06:00"
  max_allocated_storage           = var.max_allocated_storage
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection      = var.deletion_protection
  delete_automated_backups = true

  tags = {
    Name   = "postgres-${var.name}"
    UserID = var.user_id
  }

  depends_on = [aws_cloudwatch_log_group.postgres_logs]
}

#############################################
# Outputs
#############################################

output "host" {
  description = "PostgreSQL endpoint address"
  value       = aws_db_instance.postgres.address
}

output "port" {
  description = "PostgreSQL port"
  value       = tostring(aws_db_instance.postgres.port)
}

output "username" {
  description = "PostgreSQL master username"
  value       = var.rds_username
}

output "password" {
  description = "PostgreSQL master password"
  value       = random_password.postgres_password.result
  sensitive   = true
}

output "database" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "arn" {
  description = "PostgreSQL RDS ARN"
  value       = aws_db_instance.postgres.arn
}

output "identifier" {
  description = "PostgreSQL RDS identifier"
  value       = aws_db_instance.postgres.identifier
}