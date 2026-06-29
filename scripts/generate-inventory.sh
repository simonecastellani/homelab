#!/usr/bin/env bash
# Generate Ansible inventory.yml from Terraform outputs (inventory.json).
# Usage: ./scripts/generate-inventory.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INVENTORY_JSON="$REPO_ROOT/ansible/inventory.json"

cat > "$REPO_ROOT/ansible/inventory.yml" <<EOF
# Generated from Terraform outputs — do not edit manually.
---
all:
  children:
    dns:
      hosts:
        pihole:
          ansible_host: $(jq -r '.guests.value.pihole.static_ip' "$INVENTORY_JSON")
          ansible_user: root
    home_automation:
      hosts:
        homeassistant:
          ansible_host: $(jq -r '.guests.value.homeassistant.static_ip' "$INVENTORY_JSON")
          ansible_user: root
EOF

echo "Inventory generated successfully."
