output "bucket_name" {
  value = var.bucket_name != "" ? var.bucket_name : google_storage_bucket.state[0].name
}
