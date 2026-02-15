output "project_id" {
  value = var.project_id
}

output "global_ip" {
  value = module.networking.global_ip
}

output "service_urls" {
  value = module.cloud_run.service_urls
}

output "state_bucket" {
  value       = module.state_bucket.bucket_name
  description = "GCS bucket for Terraform state (configure backend to use it)"
}

output "artifact_registry_repo" {
  value       = module.artifact_registry.repository_url
  description = "Artifact Registry repo URL for mirrored gateway image"
}
