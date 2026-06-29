#!/usr/bin/env bash
# Bootstrap MinIO on the Proxmox node for Terraform S3-compatible state storage.
# Uses the standalone MinIO binary (no Docker required).
# Run this directly on the Proxmox node before the first terraform init.
#
# Usage: ssh root@192.168.178.200 'bash -s' < scripts/setup-minio.sh

set -euo pipefail

MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-$(openssl rand -base64 32)}"
DATA_DIR="/var/lib/minio-data"
MINIO_BIN="/usr/local/bin/minio"

mkdir -p "$DATA_DIR"

# --- Download MinIO server binary if not present ---
if [[ ! -x "$MINIO_BIN" ]]; then
  echo "Downloading MinIO server binary..."
  curl -sSL "https://dl.min.io/server/minio/release/linux-amd64/minio" -o "$MINIO_BIN"
  chmod +x "$MINIO_BIN"
fi

# --- Create systemd service ---
cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO S3-compatible object storage
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
Environment="MINIO_ROOT_USER=${MINIO_ROOT_USER}"
Environment="MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}"
Environment="MINIO_BROWSER_REDIRECT_URL=http://192.168.178.200:9001"
ExecStart=${MINIO_BIN} server ${DATA_DIR} --console-address :9001
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minio

echo "Waiting for MinIO to start..."
for i in {1..30}; do
  if curl -sSf "http://localhost:9000/minio/health/ready" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# --- Install MinIO client (mc) if not present ---
if ! command -v mc &>/dev/null; then
  echo "Installing mc (MinIO client)..."
  curl -sSL "https://dl.min.io/client/mc/release/linux-amd64/mc" -o /usr/local/bin/mc
  chmod +x /usr/local/bin/mc
fi

# --- Create the terraform-state bucket ---
mc alias set local "http://localhost:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --insecure || true
mc mb local/terraform-state --ignore-existing --insecure || true

echo ""
echo "=== MinIO bootstrap complete ==="
echo "Endpoint:     http://192.168.178.200:9000"
echo "Console:      http://192.168.178.200:9001"
echo "Access Key:   $MINIO_ROOT_USER"
echo "Secret Key:   $MINIO_ROOT_PASSWORD"
echo "Bucket:       terraform-state"
echo ""
echo "Store these as GitHub secrets: MINIO_ACCESS_KEY and MINIO_SECRET_KEY"
