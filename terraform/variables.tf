variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "infisical_universal_auth_client_id" {
  type = string
}

variable "infisical_universal_auth_client_secret" {
  type = string
}

variable "infisical_project_id" {
  type = string
}

variable "infisical_api_url" {
  type = string
}