# Home Assistant runs in a native Debian LXC with Docker installed by Ansible.
# This gives us SSH access for configuration management and simplifies migration
# from the existing Raspberry Pi Docker setup.

resource "proxmox_virtual_environment_container" "homeassistant" {
  node_name = var.proxmox_node
  vm_id     = 202

  description = "Home Assistant (Docker in LXC)"

  initialization {
    hostname = var.guests["homeassistant"].hostname

    ip_config {
      ipv4 {
        address = "${var.guests["homeassistant"].static_ip}/24"
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
    cores = var.guests["homeassistant"].cores
  }

  memory {
    dedicated = var.guests["homeassistant"].memory
  }

  disk {
    datastore_id = var.guests["homeassistant"].storage
    size         = var.guests["homeassistant"].disk
  }

  features {
    nesting = true
  }

  # Docker inside an unprivileged LXC requires keyctl and additional cgroup
  # allowances. If the provider does not expose these, apply them manually
  # via the Proxmox node after creation:
  #   echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >> /etc/pve/lxc/202.conf
  #   echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> /etc/pve/lxc/202.conf
}
