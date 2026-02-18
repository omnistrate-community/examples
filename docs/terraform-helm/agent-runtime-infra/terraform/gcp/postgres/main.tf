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
  description = "VPC network ID for private IP configuration"
  type        = string
  default     = ""
}

variable "tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-4096"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "ha" {
  description = "Enable high availability (REGIONAL)"
  type        = bool
  default     = false
}

variable "db_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
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

resource "random_id" "db_suffix" {
  byte_length = 4
}

#############################################
# Password Generation
#############################################

resource "random_password" "postgres_password" {
  length      = 20
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

#############################################
# Cloud SQL PostgreSQL Instance
#############################################

resource "google_sql_database_instance" "postgres" {
  name             = "postgres-${var.name}-${random_id.db_suffix.hex}"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  deletion_protection = false

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = var.ha ? "REGIONAL" : "ZONAL"

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }
    }

    maintenance_window {
      day          = 1
      hour         = 4
      update_track = "stable"
    }

    user_labels = {
      name    = "postgres-${var.name}"
      user-id = lower(replace(var.user_id, "[^a-z0-9_-]", ""))
    }
  }
}

#############################################
# Database
#############################################

resource "google_sql_database" "database" {
  name     = "agent_runtime"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

#############################################
# Database User
#############################################

resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = random_password.postgres_password.result
  project  = var.project_id
}

#############################################
# Outputs
#############################################

output "host" {
  description = "PostgreSQL connection IP address"
  value       = google_sql_database_instance.postgres.public_ip_address
}

output "port" {
  description = "PostgreSQL port"
  value       = "5432"
}

output "username" {
  description = "PostgreSQL username"
  value       = var.db_username
}

output "password" {
  description = "PostgreSQL password"
  value       = random_password.postgres_password.result
  sensitive   = true
}

output "database" {
  description = "PostgreSQL database name"
  value       = google_sql_database.database.name
}

output "connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.postgres.connection_name
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.postgres.name
}
