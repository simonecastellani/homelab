resource "proxmox_virtual_environment_container" "pihole" {
  node_name = var.proxmox_node
  vm_id     = 201

  description = "Pi-hole DNS server"

  initialization {
    hostname = var.guests["pihole"].hostname

    ip_config {
      ipv4 {
        address = "${var.guests["pihole"].static_ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      domain  = "lan"
      servers = var.nameservers
    }

    user_account {
      keys = [trimspace(var.ssh_public_key)]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = var.bridge
    enabled = true
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.debian_12_template.id
    type             = "debian"
  }

  cpu {
    cores = var.guests["pihole"].cores
  }

  memory {
    dedicated = var.guests["pihole"].memory
  }

  disk {
    datastore_id = var.guests["pihole"].storage
    size         = var.guests["pihole"].disk
  }

  features {
    nesting = true
  }

  # NOTE: Unprivileged LXC cannot bind port 53 without additional capabilities.
  # The Ansible role adds `lxc.cap.add: net_bind_service` to the host's
  # /etc/pve/lxc/201.conf after the guest is created.
}
