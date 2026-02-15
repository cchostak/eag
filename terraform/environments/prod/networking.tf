module "networking" {
  source = "../../modules/networking"

  project_id      = var.project_id
  tailscale_cidrs = var.tailscale_cidrs
  cloud_run_negs  = module.cloud_run.neg_ids
  domain          = var.domain
  name_suffix     = var.name_suffix
}
