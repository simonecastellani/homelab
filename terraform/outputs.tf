output "guests" {
  description = "Guest details for Ansible inventory generation"
  value = {
    pihole = {
      hostname  = proxmox_virtual_environment_container.pihole.initialization[0].hostname
      static_ip = var.guests["pihole"].static_ip
      role      = var.guests["pihole"].role
    }
    homeassistant = {
      hostname  = proxmox_virtual_environment_container.homeassistant.initialization[0].hostname
      static_ip = var.guests["homeassistant"].static_ip
      role      = var.guests["homeassistant"].role
    }
  }
}
