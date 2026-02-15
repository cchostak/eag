output "project_id" {
  value = var.project_id
}

output "global_ip" {
  value       = module.networking.global_ip
  description = "Global IP address - point your DNS here"
}

output "service_urls" {
  value = module.cloud_run.service_urls
}

output "state_bucket" {
  value       = module.state_bucket.bucket_name
  description = "GCS bucket for Terraform state (configure backend to use it)"
}

output "dns_instructions" {
  value = "Create an A record for ${var.domain} pointing to ${module.networking.global_ip}"
}

output "artifact_registry_repo" {
  value       = module.artifact_registry.repository_url
  description = "Artifact Registry repo URL for mirrored gateway image"
}
