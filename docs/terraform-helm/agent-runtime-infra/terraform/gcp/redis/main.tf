terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "google" {
  project = "{{ $sys.deployment.cloudProviderAccountID }}"
  region  = "{{ $sys.deploymentCell.region }}"
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

variable "project_id" {
  type    = string
  default = "{{ $sys.deployment.cloudProviderAccountID }}"
}

variable "network_id" {
  type    = string
  default = "{{ $sys.deploymentCell.cloudProviderNetworkID }}"
}

# User and Org labels from Omnistrate tenant parameters
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
variable "tier" {
  description = "Memorystore Redis tier"
  type        = string
  default     = "BASIC"
}

variable "memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "ha" {
  description = "Enable high availability (STANDARD_HA tier)"
  type        = bool
  default     = false
}

variable "replica_count" {
  description = "Number of replicas (only for STANDARD_HA)"
  type        = number
  default     = 1
}

#############################################
# Common Labels with User and Org Information
#############################################

locals {
  common_labels = {
    managed-by   = "omnistrate"
    instance-id  = lower(var.name)
    user-id      = lower(var.user_id)
    org-id       = lower(var.org_id)
    environment  = lower("{{ $sys.deploymentCell.environmentType }}")
    service-id   = lower("{{ $sys.deployment.serviceID }}")
    plan-id      = lower("{{ $sys.deployment.planID }}")
  }

  redis_tier = var.ha ? "STANDARD_HA" : "BASIC"
}

#############################################
# Random suffix for unique naming
#############################################

resource "random_id" "redis_suffix" {
  byte_length = 4
}

#############################################
# Memorystore Redis Instance
#############################################

resource "google_redis_instance" "redis" {
  name           = "redis-${var.name}-${random_id.redis_suffix.hex}"
  tier           = local.redis_tier
  memory_size_gb = var.memory_size_gb
  region         = var.region
  project        = var.project_id

  redis_version      = "REDIS_7_0"
  display_name       = "Redis ${var.name}"

  auth_enabled               = true
  transit_encryption_mode    = "SERVER_AUTHENTICATION"

  # For HA tier only
  replica_count      = var.ha ? var.replica_count : null
  read_replicas_mode = var.ha ? "READ_REPLICAS_ENABLED" : "READ_REPLICAS_DISABLED"

  maintenance_policy {
    weekly_maintenance_window {
      day = "MONDAY"
      start_time {
        hours   = 4
        minutes = 0
      }
    }
  }

  labels = local.common_labels
}

#############################################
# Outputs - Exposed to Omnistrate
#############################################

output "host" {
  description = "Redis host address"
  value       = google_redis_instance.redis.host
}

output "port" {
  description = "Redis port"
  value       = tostring(google_redis_instance.redis.port)
}

output "password" {
  description = "Redis auth string"
  value       = google_redis_instance.redis.auth_string
  sensitive   = true
}

output "instance_name" {
  description = "Redis instance name"
  value       = google_redis_instance.redis.name
}

output "read_endpoint" {
  description = "Redis read endpoint (for HA)"
  value       = try(google_redis_instance.redis.read_endpoint, "")
}

output "read_endpoint_port" {
  description = "Redis read endpoint port (for HA)"
  value       = try(tostring(google_redis_instance.redis.read_endpoint_port), "")
}
