resource "google_compute_region_network_endpoint_group" "eag" {
  for_each = toset(var.regions)

  name                  = "eag-neg${var.name_suffix}-${each.value}"
  project               = var.project_id
  region                = each.value
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.eag[each.value].name
  }
}
