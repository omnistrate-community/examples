terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

#############################################
# Provider
#############################################

provider "aws" {
  region = var.region
}

#############################################
# KMS Key for Encryption
#############################################

resource "aws_kms_key" "main" {
  description             = "KMS key for agent-runtime ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name   = "agent-runtime-key-${var.name}"
    UserID = var.user_id
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/agent-runtime-${var.name}"
  target_key_id = aws_kms_key.main.key_id
}

#############################################
# Outputs
#############################################

output "arn" {
  description = "KMS Key ARN"
  value       = aws_kms_key.main.arn
}

output "key_id" {
  description = "KMS Key ID"
  value       = aws_kms_key.main.key_id
}

output "alias" {
  description = "KMS Key Alias"
  value       = aws_kms_alias.main.name
}