resource "proxmox_download_file" "ubuntu_image" {
  content_type        = "import"
  datastore_id        = "local"
  node_name           = var.proxmox_node
  url                 = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
  file_name           = "ubuntu-24.04-resolute-server-cloudimg-amd64.qcow2"
  overwrite_unmanaged = true
  overwrite           = false
}

resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node
  file_mode    = "0600"

  source_raw {
    file_name = "${var.vm_id}-user-data.yaml"
    data = templatefile("${path.module}/user-data.yaml.tftpl",
      {
        ssh_keys                               = var.ssh_keys
        node_name                              = var.node_name
        ip                                     = var.ip
        infisical_universal_auth_client_id     = var.infisical_universal_auth_client_id
        infisical_universal_auth_client_secret = var.infisical_universal_auth_client_secret
        infisical_project_id                   = var.infisical_project_id
        infisical_api_url                      = var.infisical_api_url
      }
    )
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
    import_from  = proxmox_download_file.ubuntu_image.id
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

resource "null_resource" "kubeconfig" {
  depends_on = [proxmox_virtual_environment_vm.vm]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ip
      private_key = file(pathexpand(var.ssh_private_key_path))
    }
    inline = [
      "until systemctl is-active --quiet k3s; do echo 'Waiting for k3s...'; sleep 10; done"
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@${var.ip} \
        'cat /etc/rancher/k3s/k3s.yaml' \
        | sed 's/127.0.0.1/${var.ip}/g' \
        > ${path.root}/../kubeconfig.yaml
    EOT
  }
}

resource "null_resource" "flux_bootstrap" {
  depends_on = [null_resource.kubeconfig]

  provisioner "local-exec" {
    command = <<-EOT
      flux bootstrap github \
        --owner=${var.github_owner} \
        --repository=${var.github_repository} \
        --branch=${var.github_branch} \
        --path=kubernetes \
        --personal
    EOT
    environment = {
      KUBECONFIG   = "${path.root}/../kubeconfig.yaml"
      GITHUB_TOKEN = var.github_token
    }
  }
}