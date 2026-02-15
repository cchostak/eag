locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : lower(replace("${var.project_id}-eag-tf-state${var.name_suffix}", "_", "-"))
}
