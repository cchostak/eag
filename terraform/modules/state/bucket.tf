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
