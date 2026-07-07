output "guests" {
  description = "Guest details for Ansible inventory generation"
  value = {
    for key, guest in proxmox_virtual_environment_container.guests : key => {
      hostname  = guest.initialization[0].hostname
      static_ip = var.guests[key].static_ip
      role      = var.guests[key].role
    }
  }
}
