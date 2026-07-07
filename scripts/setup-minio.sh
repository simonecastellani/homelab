#!/usr/bin/env bash
# Convenience wrapper: bootstrap MinIO via Ansible.
# The real work lives in ansible/roles/minio/.
#
# Usage:
#   ./scripts/setup-minio.sh --extra-vars "minio_root_password=SECRET"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

# Ensure configs are generated
if [[ ! -f ansible/inventory-bootstrap.yml ]]; then
  ./scripts/generate-configs.sh
fi

echo "Bootstrapping MinIO via Ansible..."
ansible-playbook -i ansible/inventory-bootstrap.yml ansible/bootstrap.yml \
  --tags minio \
  "$@"
