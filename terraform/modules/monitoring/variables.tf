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
