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
  description = "GCP region to deploy resources in"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "network_id" {
  description = "VPC network ID for the Redis instance"
  type        = string
  default     = ""
}

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
# Provider
#############################################

provider "google" {
  project = var.project_id
  region  = var.region
}

#############################################
# Random suffix for unique naming
#############################################

resource "random_id" "redis_suffix" {
  byte_length = 4
}

#############################################
# Locals
#############################################

locals {
  redis_tier = var.ha ? "STANDARD_HA" : "BASIC"
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

  labels = {
    name    = "redis-${var.name}"
    user-id = lower(replace(var.user_id, "[^a-z0-9_-]", ""))
  }
}

#############################################
# Outputs
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
