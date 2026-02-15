variable "project_id" {
  type = string
}

variable "bucket_name" {
  type        = string
  description = "Optional override for the Terraform state bucket"
  default     = ""
}

variable "location" {
  type    = string
  default = "us"
}

variable "name_suffix" {
  type    = string
  default = ""
}
