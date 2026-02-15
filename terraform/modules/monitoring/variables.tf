variable "project_id" {
  type = string
}

variable "notification_email" {
  type        = string
  description = "Email for alerts"
}

variable "service_name" {
  type    = string
  default = "eag-gateway"
}
