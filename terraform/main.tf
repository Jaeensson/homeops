module "opensuse_vm" {
  source           = "./modules/opensuse_vm"
  node_name        = "opensuse-vm-01"
  vm_id            = 101
  proxmox_node     = var.proxmox_node
  proxmox_endpoint = var.proxmox_endpoint
  proxmox_token    = var.proxmox_token

  infisical_universal_auth_client_id     = var.infisical_universal_auth_client_id
  infisical_universal_auth_client_secret = var.infisical_universal_auth_client_secret
  infisical_project_id                   = var.infisical_project_id
  infisical_api_url                      = var.infisical_api_url

  network_gateway      = "192.168.1.1"
  network_netmask      = "/22"
  network_dns          = ["192.168.1.21"]
  ip                   = "192.168.0.99"
  cpu_cores            = "4"
  ram_mb               = "4096"
  system_disk_size_gb  = "50"
  storage_disk_size_gb = "200"

  ssh_keys = data.http.ssh_keys.response_body
}

data "http" "ssh_keys" {
  url = "https://github.com/Jaeensson.keys"
}
