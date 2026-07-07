#!/usr/bin/env bash
# Generate Ansible inventory.yml from Terraform outputs (inventory.json).
# Usage: ./scripts/generate-inventory.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INVENTORY_JSON="$REPO_ROOT/ansible/inventory.json"

# Build the inventory dynamically from the Terraform output map.
# Each guest's role determines its Ansible group.
exec > "$REPO_ROOT/ansible/inventory.yml"

echo "# Generated from Terraform outputs — do not edit manually."
echo "---"
echo "all:"
echo "  children:"

# Group guests by role. Since multiple guests may share a role (e.g. two
# DNS servers), we collect and emit groups.
jq -r '
  .guests.value
  | to_entries
  | group_by(.value.role)
  | .[]
  | "    \(.[0].value.role):",
    "      hosts:",
    (.[] | "        \(.key):",
           "          ansible_host: \(.value.static_ip)",
           "          ansible_user: root")
' "$INVENTORY_JSON"

echo "Inventory generated successfully." >&2
