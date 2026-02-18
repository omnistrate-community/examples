terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
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
  description = "GCP region to deploy resources in"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

#############################################
# Provider
#############################################

provider "google" {
  project = var.project_id
  region  = var.region
}

#############################################
# KMS Key Ring and Key for Encryption
#############################################

resource "google_kms_key_ring" "main" {
  name     = "agent-runtime-keyring-${var.name}"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "main" {
  name            = "agent-runtime-key-${var.name}"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days

  labels = {
    name    = "agent-runtime-key-${var.name}"
    user-id = lower(replace(var.user_id, "[^a-z0-9_-]", ""))
  }

  lifecycle {
    prevent_destroy = false
  }
}

#############################################
# Outputs
#############################################

output "key_ring_id" {
  description = "KMS Key Ring ID"
  value       = google_kms_key_ring.main.id
}

output "key_id" {
  description = "KMS Crypto Key ID"
  value       = google_kms_crypto_key.main.id
}

output "key_name" {
  description = "KMS Crypto Key Name"
  value       = google_kms_crypto_key.main.name
}
