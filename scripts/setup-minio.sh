#!/usr/bin/env bash
# Bootstrap MinIO on the Proxmox host for Terraform S3-compatible state storage.
# Run this directly on the Proxmox node before the first terraform init.
#
# Usage: ssh root@192.168.178.200 'bash -s' < scripts/setup-minio.sh

set -euo pipefail

MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-$(openssl rand -base64 32)}"
DATA_DIR="/var/lib/minio-data"

mkdir -p "$DATA_DIR"

# Run MinIO via Docker if available, otherwise fallback to standalone binary
if command -v docker &>/dev/null; then
  docker run -d \
    --name minio \
    --restart unless-stopped \
    -p 9000:9000 \
    -p 9001:9001 \
    -v "$DATA_DIR:/data" \
    -e "MINIO_ROOT_USER=$MINIO_ROOT_USER" \
    -e "MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD" \
    quay.io/minio/minio:latest server /data --console-address ":9001"
else
  echo "Docker not found. Install Docker first, or download MinIO binary from https://min.io/download"
  exit 1
fi

echo "MinIO is starting..."
sleep 3

# Create the terraform-state bucket using the MinIO client (mc)
if ! command -v mc &>/dev/null; then
  echo "Installing mc (MinIO client)..."
  curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc
  chmod +x /usr/local/bin/mc
fi

mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" --insecure || true
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
