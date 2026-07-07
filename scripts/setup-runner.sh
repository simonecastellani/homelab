#!/usr/bin/env bash
# Convenience wrapper: bootstrap GitHub Actions runner via Ansible.
# The real work lives in ansible/roles/github_runner/.
#
# Usage:
#   ./scripts/setup-runner.sh \
#     --extra-vars "github_repo=https://github.com/ORG/REPO" \
#     --extra-vars "github_runner_token=TOKEN"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

# Ensure configs are generated
if [[ ! -f ansible/inventory-bootstrap.yml ]]; then
  ./scripts/generate-configs.sh
fi

echo "Bootstrapping GitHub Actions runner via Ansible..."
ansible-playbook -i ansible/inventory-bootstrap.yml ansible/bootstrap.yml \
  --tags github_runner \
  "$@"
