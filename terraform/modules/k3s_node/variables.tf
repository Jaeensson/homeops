variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_storage" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "cpu_type" {
  description = "CPU architecture type"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "network_gateway" {
  description = "Gateway for network configuration"
  type        = string
  default     = "192.168.1.1"
}

variable "network_netmask" {
  description = "Netmask for network configuration"
  type        = string
  default     = "/24"
}

variable "network_dns" {
  description = "Netmask for network configuration"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Proxmox network bridge device"
  type        = string
  default     = "vmbr0"
}

variable "vm_id" {
  type = number
}

variable "proxmox_node" {
  type = string
}

variable "node_name" {
  type = string
}

variable "ip" {
  type = string
}

variable "cpu_cores" {
  type = number
}

variable "ram_mb" {
  type = number
}

variable "system_disk_size_gb" {
  type = number
}

variable "storage_disk_size_gb" {
  type = number
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used to connect to the VM"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_keys" {
  type        = string
  description = "SSH keys for VM access"
}

variable "usb_devices" {
  type = list(object({
    host = string
    usb3 = bool
  }))
  default = []
}

variable "pci_device" {
  type = object({
    device = string
    id     = string
    pcie   = bool
    rombar = bool
    xvga   = bool
  })
  default = {
    device = ""
    id     = ""
    pcie   = false
    rombar = false
    xvga   = false
  }
}

