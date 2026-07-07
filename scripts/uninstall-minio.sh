#!/usr/bin/env bash
# Uninstall MinIO from the Proxmox node via Ansible.
#
# Usage:
#   ./scripts/uninstall-minio.sh
#   ./scripts/uninstall-minio.sh --extra-vars "minio_remove_data=true"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

# Ensure configs are generated
if [[ ! -f ansible/inventory-bootstrap.yml ]]; then
  ./scripts/generate-configs.sh
fi

echo "Uninstalling MinIO via Ansible..."
ansible-playbook -i ansible/inventory-bootstrap.yml ansible/uninstall.yml \
  --tags minio \
  "$@"
