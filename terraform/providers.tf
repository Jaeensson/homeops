terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.101.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_token
  insecure  = true

  ssh {
    agent    = true
    username = "root"
  }
}