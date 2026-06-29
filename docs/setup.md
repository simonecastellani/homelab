# Homelab Setup Guide

Step-by-step bootstrap for a fresh Proxmox node. Run these in order.

## 1. Proxmox Node Preparation

Ensure your Proxmox node (`192.168.178.200`) is installed and reachable. The
node should have:

- Static IP `192.168.178.200/24` on `vmbr0`
- Gateway `192.168.178.1`
- Docker installed (for MinIO; optional if you use a standalone MinIO binary)

## 2. Bootstrap MinIO (Terraform State Backend)

Terraform needs an S3-compatible backend to store state before it can manage
anything. MinIO runs on the Proxmox host.

```bash
# SSH to the Proxmox node
ssh root@192.168.178.200

# Run the bootstrap script
curl -sSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/scripts/setup-minio.sh | bash
```

Or copy `scripts/setup-minio.sh` to the node and run it directly.

The script will output an **Access Key** and **Secret Key**. Save these:

| Secret | Value |
|--------|-------|
| `MINIO_ACCESS_KEY` | The access key printed by the script |
| `MINIO_SECRET_KEY` | The secret key printed by the script |

## 3. Register GitHub Actions Self-Hosted Runner

The runner can live on the Proxmox host or inside a dedicated LXC. Running it
on the host is simplest.

1. Go to your GitHub repo → **Settings → Actions → Runners → New self-hosted runner**
2. Select **Linux** and copy the registration token.
3. On the Proxmox node:

```bash
export GITHUB_REPO="https://github.com/YOUR_ORG/YOUR_REPO"
export GITHUB_TOKEN="PASTE_TOKEN_HERE"
./scripts/setup-runner.sh
```

Verify the runner appears as **Idle** in the GitHub UI.

## 4. Configure CI Secrets

Go to **GitHub repo → Settings → Secrets and variables → Actions** and add:

| Secret | How to obtain |
|--------|---------------|
| `PROXMOX_API_TOKEN` | Proxmox UI → Datacenter → Permissions → API Tokens → Add. Format: `USER@realm!TOKENID=SECRET` |
| `SSH_PUBLIC_KEY` | Contents of `~/.ssh/id_rsa.pub` (the key you will use to SSH into guests) |
| `MINIO_ACCESS_KEY` | From step 2 |
| `MINIO_SECRET_KEY` | From step 2 |
| `PIHOLE_ADMIN_PASSWORD` | Choose a strong password for the Pi-hole web UI |

## 5. Initialize Terraform

On your local machine (or the runner, once it's online):

```bash
# Clone the repo
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO

# Generate Terraform and Ansible configs from config.yml
./scripts/generate-configs.sh

# Initialize Terraform (this connects to MinIO for state)
cd terraform
terraform init
```

If `terraform init` fails because the MinIO endpoint is unreachable, verify:
- MinIO container is running on Proxmox (`docker ps`)
- Port 9000 is not blocked by Proxmox firewall (`iptables -L`)

## 6. First Apply (Infrastructure Only)

```bash
cd terraform
export TF_VAR_proxmox_api_token="YOUR_TOKEN_HERE"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
terraform apply
```

This creates:
- Two LXCs (VM IDs 201 and 202)
- Network configuration with static IPs
- Auto-downloaded Debian 12 template

## 7. Migrate Home Assistant Configuration

Before running Ansible for the first time, copy your existing Home Assistant
`/config` from the Raspberry Pi to the new LXC:

```bash
# From the Raspberry Pi, or any host with SSH to both:
rsync -avz --progress /config/ root@192.168.178.202:/opt/homeassistant/config/
```

## 8. Deploy Applications (Ansible)

Run the full Ansible playbook via the CI workflow:

1. Push a commit to `main` (or open a PR and merge it).
2. Go to **Actions → Terraform Apply + Ansible Deploy**.
3. Click **Run workflow** to trigger a manual apply.

Or run Ansible manually from the runner:

```bash
cd ansible
./scripts/generate-inventory.sh  # requires terraform output from step 6
ansible-playbook -i inventory.yml playbook.yml \
  --extra-vars "pihole_admin_password=YOUR_PASSWORD_HERE"
```

## 9. Verify

| Service | URL | Expected Result |
|---------|-----|----------------|
| Pi-hole admin | http://192.168.178.201/admin | Login with your password |
| Home Assistant | http://192.168.178.202:8123 | Existing config loaded |
| MinIO console | http://192.168.178.200:9001 | Terraform state bucket visible |

## Troubleshooting

### Pi-hole cannot bind port 53

If the unprivileged LXC cannot bind port 53, the Ansible role should have
added `lxc.cap.add: net_bind_service` to `/etc/pve/lxc/201.conf`. Verify:

```bash
cat /etc/pve/lxc/201.conf | grep cap.add
pct restart 201
```

### Docker fails inside Home Assistant LXC

Check the raw LXC config on the host:

```bash
cat /etc/pve/lxc/202.conf | grep -E "(cgroup2|keyctl|nesting)"
pct restart 202
```

Required lines:
```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
features: nesting=1,keyctl=1
```

### Terraform state locked

If a previous apply was interrupted, the state lock may remain in MinIO:

```bash
# Remove the lock object from MinIO (via mc or MinIO console)
mc rm local/terraform-state/homelab/terraform.tfstate.tflock --insecure --force
```
