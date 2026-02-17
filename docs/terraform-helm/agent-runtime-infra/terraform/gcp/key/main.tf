terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
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

#############################################
# Common Labels with User and Org Information
#############################################

locals {
  # Sanitize labels for GCP (lowercase, alphanumeric and underscores/hyphens only)
  common_labels = {
    managed-by   = "omnistrate"
    instance-id  = lower(var.name)
    user-id      = lower(var.user_id)
    org-id       = lower(var.org_id)
    environment  = lower("{{ $sys.deploymentCell.environmentType }}")
    service-id   = lower("{{ $sys.deployment.serviceID }}")
    plan-id      = lower("{{ $sys.deployment.planID }}")
  }
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

  labels = local.common_labels

  lifecycle {
    prevent_destroy = false
  }
}

#############################################
# Outputs - Exposed to Omnistrate
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
