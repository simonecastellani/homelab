#!/usr/bin/env bash
# Generate terraform.tfvars and ansible/group_vars/all.yml from config.yml.
# Usage: ./scripts/generate-configs.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/config.yml"

if ! command -v yq &>/dev/null; then
  echo "Error: yq is required. Install with: pip install yq  or  wget ..."
  exit 1
fi
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required."
  exit 1
fi

# --- Terraform tfvars ---
{
  echo "# Generated from config.yml — do not edit manually."
  echo "proxmox_host     = \"$(yq -r '.proxmox.host' "$CONFIG")\""
  echo "proxmox_node     = \"$(yq -r '.proxmox.node' "$CONFIG")\""
  echo "proxmox_port     = $(yq -r '.proxmox.port' "$CONFIG")"
  echo "proxmox_token_id = \"$(yq -r '.proxmox.token_id' "$CONFIG")\""
  echo "bridge           = \"$(yq -r '.network.bridge' "$CONFIG")\""
  echo "gateway          = \"$(yq -r '.network.gateway' "$CONFIG")\""
  echo "nameservers      = $(yq -r '.network.nameservers | @json' "$CONFIG")"
  echo ""
  echo "guests = {"

  # Use jq for the nested guest blocks — yq string concatenation gets
  # unwieldy with optional features and device_passthrough lists.
  yq -r '
    .guests | to_entries[] |
    "  \(.key) = {\n" +
    "    hostname    = \"\(.value.hostname)\"\n" +
    "    role        = \"\(.value.role)\"\n" +
    "    static_ip   = \"\(.value.static_ip)\"\n" +
    "    vm_id       = \(.value.vm_id)\n" +
    "    description = \"\(.value.description)\"\n" +
    "    cores       = \(.value.cores)\n" +
    "    memory      = \(.value.memory)\n" +
    "    disk        = \(.value.disk)\n" +
    "    storage     = \"\(.value.storage)\"\n" +
    (if .value.docker_image then "    docker_image = \"\(.value.docker_image)\"\n" else "" end) +
    (if .value.features then
      "    features = {\n" +
      (if .value.features.nesting      then "      nesting      = true\n"  else "" end) +
      (if .value.features.keyctl       then "      keyctl       = true\n"  else "" end) +
      (if .value.features.unprivileged then "      unprivileged = true\n" else "" end) +
      "    }\n"
    else "" end) +
    (if .value.device_passthrough then
      "    device_passthrough = [\n" +
      (.value.device_passthrough | map(
        "      { path = \"\(.path)\" }"
      ) | join(",\n")) +
      "\n    ]\n"
    else "" end) +
    "  }"
  ' "$CONFIG"

  echo "}"
} > "$REPO_ROOT/terraform/terraform.tfvars"

# --- Ansible group_vars ---
# Only Ansible-relevant fields (no features, no device_passthrough).
mkdir -p "$REPO_ROOT/ansible/group_vars"
{
  echo "# Generated from config.yml — do not edit manually."
  echo "---"
  echo "proxmox_host: \"$(yq -r '.proxmox.host' "$CONFIG")\""
  echo "lan_subnet: \"$(yq -r '.network.lan_subnet' "$CONFIG")\""
  echo "gateway: \"$(yq -r '.network.gateway' "$CONFIG")\""
  echo "nameservers:"
  yq -r '.network.nameservers[]' "$CONFIG" | sed 's/^/  - "/; s/$/"/'
  echo ""
  echo "guests:"
  yq -r '.guests | to_entries | .[] |
    "  " + .key + ":\n" +
    "    hostname: " + .value.hostname + "\n" +
    "    role: " + .value.role + "\n" +
    "    static_ip: " + .value.static_ip + "\n" +
    "    vm_id: " + (.value.vm_id | tostring) + "\n" +
    "    cores: " + (.value.cores | tostring) + "\n" +
    "    memory: " + (.value.memory | tostring) + "\n" +
    "    disk: " + (.value.disk | tostring) + "\n" +
    (if .value.docker_image then "    docker_image: " + .value.docker_image + "\n" else "" end)
  ' "$CONFIG"
} > "$REPO_ROOT/ansible/group_vars/all.yml"

# --- Ansible bootstrap inventory ---
{
  echo "# Generated from config.yml — do not edit manually."
  echo "---"
  echo "proxmox:"
  echo "  hosts:"
  echo "    pve:"
  echo "      ansible_host: $(yq -r '.proxmox.host' "$CONFIG")"
  echo "      ansible_user: root"
} > "$REPO_ROOT/ansible/inventory-bootstrap.yml"

echo "Configs generated successfully."
