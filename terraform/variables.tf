variable "proxmox_host" {
  description = "IP address of the Proxmox node"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "proxmox_port" {
  description = "Proxmox API port"
  type        = number
  default     = 8006
}

variable "proxmox_api_token" {
  description = "Full Proxmox API token string (id=secret)"
  type        = string
  sensitive   = true
}

variable "bridge" {
  description = "Proxmox bridge interface for guest networking"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "LAN gateway IP"
  type        = string
}

variable "nameservers" {
  description = "DNS nameservers for guests"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_public_key" {
  description = "SSH public key to inject into guests"
  type        = string
}

variable "guests" {
  description = "Map of guest definitions"
  type = map(object({
    hostname  = string
    role      = string
    static_ip = string
    cores     = number
    memory    = number
    disk      = number
    storage   = string
    docker_image = optional(string)
  }))
}
