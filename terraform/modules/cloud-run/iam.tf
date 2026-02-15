resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = toset(var.regions)

  project  = var.project_id
  location = each.value
  name     = google_cloud_run_v2_service.eag[each.value].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
