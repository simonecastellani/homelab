# Auto-download the Debian 12 LXC template if not already present on storage.
# This eliminates a manual pre-requisite step.

resource "proxmox_virtual_environment_download_file" "debian_12_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_node
  file_name    = "debian-12-standard_12.7-1_amd64.tar.zst"
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
  overwrite    = false
}
