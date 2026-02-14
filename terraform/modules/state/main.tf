# state module - GCS bucket for Terraform state and backups

variable "project_id" {
  type = string
}

variable "bucket_name" {
  type        = string
  description = "Optional override for the Terraform state bucket"
  default     = ""
}

variable "location" {
  type    = string
  default = "us"
}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : lower(replace("${var.project_id}-eag-tf-state", "_", "-"))
}

resource "google_storage_bucket" "state" {
  name                        = local.bucket_name
  location                    = var.location
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = false
  public_access_prevention    = "enforced"
  versioning {
    enabled = true
  }
}

output "bucket_name" {
  value = google_storage_bucket.state.name
}
