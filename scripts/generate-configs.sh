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

# --- Terraform tfvars ---
{
  echo "# Generated from config.yml — do not edit manually."
  echo "proxmox_host     = \"$(yq -r '.proxmox.host' "$CONFIG")\""
  echo "proxmox_node     = \"$(yq -r '.proxmox.node' "$CONFIG")\""
  echo "proxmox_port     = $(yq -r '.proxmox.port' "$CONFIG")"
  echo "proxmox_token_id = \"$(yq -r '.proxmox.token_id' "$CONFIG")\""
  echo "bridge           = \"$(yq -r '.network.bridge' "$CONFIG")\""
  echo "gateway          = \"$(yq -r '.network.gateway' "$CONFIG")\""
  echo "nameservers      = [$(yq -r '.network.nameservers | map("\\"\(.\\"")") | join(", ")' "$CONFIG")]"
  echo ""
  echo "guests = {"
  yq -r '.guests | to_entries | .[] |
    "  " + .key + " = {\n" +
    "    hostname  = \"" + .value.hostname + "\"\n" +
    "    role      = \"" + .value.role + "\"\n" +
    "    static_ip = \"" + .value.static_ip + "\"\n" +
    "    cores     = " + (.value.cores | tostring) + "\n" +
    "    memory    = " + (.value.memory | tostring) + "\n" +
    "    disk      = " + (.value.disk | tostring) + "\n" +
    "    storage   = \"" + .value.storage + "\"\n" +
    (if .value.docker_image then "    docker_image = \"" + .value.docker_image + "\"\n" else "" end) +
    "  }"
  ' "$CONFIG"
  echo "}"
} > "$REPO_ROOT/terraform/terraform.tfvars"

# --- Ansible group_vars ---
mkdir -p "$REPO_ROOT/ansible/group_vars"
{
  echo "# Generated from config.yml — do not edit manually."
  echo "---"
  echo "proxmox_host: \"$(yq -r '.proxmox.host' "$CONFIG")\""
  echo "lan_subnet: \"$(yq -r '.network.lan_subnet' "$CONFIG")\""
  echo "gateway: \"$(yq -r '.network.gateway' "$CONFIG")\""
  echo "nameservers:"
  yq -r '.network.nameservers[] | "  - \"\(.\"")"' "$CONFIG"
  echo ""
  echo "guests:"
  yq -r '.guests | to_entries | .[] |
    "  " + .key + ":\n" +
    "    hostname: " + .value.hostname + "\n" +
    "    role: " + .value.role + "\n" +
    "    static_ip: " + .value.static_ip + "\n" +
    "    cores: " + (.value.cores | tostring) + "\n" +
    "    memory: " + (.value.memory | tostring) + "\n" +
    "    disk: " + (.value.disk | tostring) + "\n" +
    (if .value.docker_image then "    docker_image: " + .value.docker_image + "\n" else "" end)
  ' "$CONFIG"
} > "$REPO_ROOT/ansible/group_vars/all.yml"

echo "Configs generated successfully."
