module "k3s_node" {
  source           = "./modules/k3s_node"
  node_name        = "k3s-node-01"
  vm_id            = 101
  proxmox_node     = var.proxmox_node
  proxmox_endpoint = var.proxmox_endpoint
  proxmox_token    = var.proxmox_token

  network_gateway     = "192.168.1.1"
  network_netmask     = "/22"
  network_dns         = ["192.168.1.1"]
  ip                  = "192.168.0.99"
  cpu_cores           = "8"
  cpu_type            = "host"
  ram_mb              = "49152"
  system_disk_size_gb = "500"

  ssh_keys = data.http.ssh_keys.response_body

  usb_devices = [
    {
      host = "0658:0200"
      usb3 = false
    },
    {
      host = "10c4:8a2a"
      usb3 = false
    }
  ]

  pci_device = {
    device = "hostpci0"
    id     = "0000:00:02"
    pcie   = false
    rombar = true
    xvga   = false
  }
}

data "http" "ssh_keys" {
  url = "https://github.com/Jaeensson.keys"
}
