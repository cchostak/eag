output "service_urls" {
  value = {
    for region, svc in google_cloud_run_v2_service.eag :
    region => svc.uri
  }
}

output "neg_ids" {
  value = {
    for region, neg in google_compute_region_network_endpoint_group.eag :
    region => neg.id
  }
}
