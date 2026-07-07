terraform {
  required_version = ">= 1.5"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:${var.proxmox_port}/"
  api_token = var.proxmox_api_token
  insecure  = true

  # Temporarily disabled while diagnosing SSL error on container create.
  # SSH is only required for idmap, snippet uploads, and disk import —
  # none of which these containers use.
  # ssh {
  #   agent    = true
  #   username = "root"
  # }
}
