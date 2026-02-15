variable "project_id" {
  type = string
}

variable "service_name" {
  type    = string
  default = "eag-gateway"
}

variable "retention_days" {
  type    = number
  default = 365
}

variable "log_bucket_location" {
  type    = string
  default = "global"
}

variable "archive_bucket_name" {
  type        = string
  description = "Optional override for the GCS archive bucket name"
  default     = ""
}

variable "archive_bucket_location" {
  type    = string
  default = "us"
}

variable "archive_retention_days" {
  type    = number
  default = 1095 # 3 years
}

variable "log_filter" {
  type    = string
  default = ""
}

variable "use_default_logging_bucket" {
  type        = bool
  default     = true
  description = "If true, logs go to _Default bucket (no bucket create permission required)."
}

variable "name_suffix" {
  type    = string
  default = ""
}
