#!/usr/bin/env bash
# Register a GitHub Actions self-hosted runner on the Proxmox host (or an LXC).
# Run this after creating a dedicated runner LXC or directly on the Proxmox node.
#
# Prerequisites:
#   - GitHub repo URL and a runner registration token from:
#     Settings → Actions → Runners → New self-hosted runner
#
# Usage:
#   export GITHUB_REPO="https://github.com/YOUR_ORG/YOUR_REPO"
#   export GITHUB_TOKEN="YOUR_REGISTRATION_TOKEN"
#   ./scripts/setup-runner.sh

set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
RUNNER_DIR="${RUNNER_DIR:-/opt/github-runner}"
RUNNER_NAME="${RUNNER_NAME:-proxmox-homelab-runner}"

if [[ -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
  echo "Error: GITHUB_REPO and GITHUB_TOKEN must be set."
  echo "Get a token from: $GITHUB_REPO/settings/actions/runners/new"
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_LABEL="linux-x64" ;;
  aarch64) ARCH_LABEL="linux-arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

LATEST=$(curl -sSL "https://api.github.com/repos/actions/runner/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
if [[ -z "$LATEST" ]]; then
  echo "Error: Could not determine latest runner version."
  exit 1
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "Downloading GitHub Actions runner v${LATEST} for ${ARCH_LABEL}..."
curl -o actions-runner.tar.gz -L "https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-${ARCH_LABEL}-${LATEST}.tar.gz"

tar xzf actions-runner.tar.gz --overwrite
rm actions-runner.tar.gz

echo "Configuring runner..."
./config.sh --url "$GITHUB_REPO" --token "$GITHUB_TOKEN" --name "$RUNNER_NAME" --unattended --replace

echo "Installing as a systemd service..."
./svc.sh install
./svc.sh start

echo ""
echo "=== Runner setup complete ==="
echo "Runner name: $RUNNER_NAME"
echo "Status:     systemctl status actions.runner.*.service"
echo "Logs:       journalctl -u actions.runner.*.service -f"
