resource "proxmox_download_file" "opensuse_image" {
  content_type        = "import"
  datastore_id        = "local"
  node_name           = var.proxmox_node
  url                 = "https://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-ContainerHost-OpenStack-Cloud.qcow2"
  file_name           = "openSUSE-MicroOS.x86_64-ContainerHost-kvm-and-xen.qcow2"
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name           = var.proxmox_node
  file_mode = "0600"


  source_file {
    path = "${path.module}/user-data.yaml"
    file_name = "${var.vm_id}-user-data.yaml"
  }
}


resource "proxmox_virtual_environment_vm" "vm" {
  name            = var.node_name
  node_name       = var.proxmox_node
  vm_id           = var.vm_id
  keyboard_layout = "sv"

  agent {
    enabled = true
  }

  startup {
    order      = "1"
    up_delay   = "30"
    down_delay = "30"
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.ram_mb
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    import_from  = proxmox_download_file.opensuse_image.id
    size         = var.system_disk_size_gb
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi1"
    size         = var.storage_disk_size_gb
  }

  network_device {
    bridge = var.network_bridge

  }

  boot_order = [
    "scsi0",
    "ide2"
  ]

  initialization {
    datastore_id = var.proxmox_storage
    ip_config {
      ipv4 {
        address = "${var.ip}${var.network_netmask}"
        gateway = var.network_gateway
      }
    }

    dns {
      domain  = "egenitres.se"
      servers = var.network_dns
    }

     user_data_file_id = proxmox_virtual_environment_file.user_data.id
  }
}