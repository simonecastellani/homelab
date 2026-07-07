#!/usr/bin/env bash
# Uninstall the GitHub Actions self-hosted runner from the Proxmox node via Ansible.
#
# Usage:
#   ./scripts/uninstall-runner.sh
#   ./scripts/uninstall-runner.sh \
#     --extra-vars "github_repo=https://github.com/ORG/REPO" \
#     --extra-vars "github_runner_token=TOKEN"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

# Ensure configs are generated
if [[ ! -f ansible/inventory-bootstrap.yml ]]; then
  ./scripts/generate-configs.sh
fi

echo "Uninstalling GitHub Actions runner via Ansible..."
ansible-playbook -i ansible/inventory-bootstrap.yml ansible/uninstall.yml \
  --tags github_runner \
  "$@"
