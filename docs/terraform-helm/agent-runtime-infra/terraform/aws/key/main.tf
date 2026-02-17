terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
# KMS Key for Encryption
#############################################

resource "aws_kms_key" "main" {
  description             = "KMS key for agent-runtime ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "agent-runtime-key-${var.name}"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/agent-runtime-${var.name}"
  target_key_id = aws_kms_key.main.key_id
}

#############################################
# Outputs - Exposed to Omnistrate
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
