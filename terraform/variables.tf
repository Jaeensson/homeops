variable "github_token" {
  description = "GitHub PAT used to bootstrap Flux"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Git branch Flux will sync from"
  type        = string
  default     = "main"
}

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