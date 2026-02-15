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

variable "name_suffix" {
  type        = string
  default     = ""
  description = "Optional suffix appended to metric and service identifiers (include leading dash if desired)"
}

variable "create_auth_metric" {
  type    = bool
  default = true
}

variable "create_auth_alert" {
  type    = bool
  default = true
}

variable "create_custom_service" {
  type    = bool
  default = true
}
