module "k3s_node" {
  source           = "./modules/k3s_node"
  node_name        = "k3s-node-01"
  vm_id            = 101
  proxmox_node     = var.proxmox_node
  proxmox_endpoint = var.proxmox_endpoint
  proxmox_token    = var.proxmox_token

  network_gateway      = "192.168.1.1"
  network_netmask      = "/22"
  network_dns          = ["192.168.1.21"]
  ip                   = "192.168.0.99"
  cpu_cores            = "4"
  cpu_type             = "host"
  ram_mb               = "32768"
  system_disk_size_gb  = "100"
  storage_disk_size_gb = "200"

  ssh_keys = data.http.ssh_keys.response_body
}

data "http" "ssh_keys" {
  url = "https://github.com/Jaeensson.keys"
}
