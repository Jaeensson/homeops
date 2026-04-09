module "opensuse_vm" {
  source           = "./modules/opensuse_vm"
  node_name        = "opensuse-vm-01"
  vm_id            = 101
  proxmox_node     = var.proxmox_node
  proxmox_endpoint = var.proxmox_endpoint
  proxmox_token    = var.proxmox_token

  network_gateway      = "192.168.1.1"
  network_netmask      = "/22"
  network_dns          = ["192.168.1.21"]
  ip                   = "192.168.0.99"
  cpu_cores            = "4"
  ram_mb               = "4096"
  system_disk_size_gb  = "50"
  storage_disk_size_gb = "200"
}
