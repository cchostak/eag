locals {
  repo_url                = module.artifact_registry.repository_url
  mirrored_gateway_image  = "${local.repo_url}/agentgateway:0.12.0"
  gateway_image_effective = var.use_artifact_registry_mirror ? local.mirrored_gateway_image : var.gateway_image
}
