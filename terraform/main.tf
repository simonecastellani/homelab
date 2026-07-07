# Stable template identifier used by all guest containers.
# The actual template file is downloaded by the Ansible proxmox_template role
# (bootstrap.yml) to this exact path on the Proxmox node.
locals {
  template_file_id = "local:vztmpl/debian-12-standard.tar.zst"
}

# All Guests are created from a single resource definition.
# Per-Guest variation (features, device passthrough, etc.) is driven by
# the var.guests map in terraform.tfvars, generated from config.yml.
resource "proxmox_virtual_environment_container" "guests" {
  for_each = var.guests

  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id
  description = each.value.description

  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = "${each.value.static_ip}/24"
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
    template_file_id = local.template_file_id
    type             = "debian"
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = each.value.storage
    size         = each.value.disk
  }

  # LXC feature flags — nesting, keyctl, unprivileged.
  # Previously split between Terraform (nesting) and Ansible (keyctl via
  # lineinfile). Now consolidated here. The one remaining exception is
  # net_bind_service for Pi-hole, which the bpg/proxmox provider does not
  # yet expose — that stays in the Pi-hole Ansible role.
  dynamic "features" {
    for_each = each.value.features != null ? [1] : []
    content {
      nesting = try(each.value.features.nesting, false)
      keyctl  = try(each.value.features.keyctl, false)
    }
  }

  unprivileged = try(each.value.features.unprivileged, false)

  # Device passthrough (e.g. /dev/net/tun for Docker-in-LXC).
  dynamic "device_passthrough" {
    for_each = each.value.device_passthrough
    content {
      path = device_passthrough.value.path
    }
  }
}
