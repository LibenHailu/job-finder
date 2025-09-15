variable "gcp_project_id" {
  type        = string
  description = "GCP project ID hosting the website bucket"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for resources (e.g., us-central1)"
}

variable "gcp_svc_key" {
  type        = string
  description = "Path to the GCP service account JSON key file"
}


variable "domain" {
  type = string
}