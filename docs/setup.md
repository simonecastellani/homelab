# Homelab Setup Guide

Step-by-step bootstrap for a fresh Proxmox node. Run these in order.

## 1. Proxmox Node Preparation

Ensure your Proxmox node (`192.168.178.200`) is installed and reachable. The
node should have:

- Static IP `192.168.178.200/24` on `vmbr0`
- Gateway `192.168.178.1`
- Internet access (for downloading templates and binaries)
- SSH access for your local machine with a key pair

## 2. Install Ansible on Your Local Machine

The bootstrap and application deployment are driven by Ansible. Install it on
the machine that will run the playbooks (your laptop or workstation):

```bash
# macOS
brew install ansible

# Debian/Ubuntu
sudo apt update && sudo apt install -y ansible

# Arch
sudo pacman -S ansible
```

## 3. Generate Configs

Clone the repo and generate all derived configuration files from `config.yml`:

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO
./scripts/generate-configs.sh
```

This creates:
- `terraform/terraform.tfvars`
- `ansible/group_vars/all.yml`
- `ansible/inventory-bootstrap.yml`

## 4. Bootstrap the Proxmox Node (MinIO + GitHub Runner)

Before Terraform can store state, the Proxmox node needs MinIO. Before GitHub
Actions can deploy, the node needs a self-hosted runner. Both are installed by
the `bootstrap.yml` playbook.

### Get a GitHub runner registration token

Go to your GitHub repo → **Settings → Actions → Runners → New self-hosted runner**
→ Select **Linux** → Copy the registration token.

### Run the bootstrap playbook

```bash
cd ansible
ansible-playbook -i inventory-bootstrap.yml bootstrap.yml \
  --extra-vars "minio_root_password=CHOOSE_A_STRONG_PASSWORD" \
  --extra-vars "github_repo=https://github.com/YOUR_ORG/YOUR_REPO" \
  --extra-vars "github_runner_token=TOKEN_FROM_GITHUB"
```

This playbook is idempotent. If you re-run it:
- The Debian 12 LXC template will be downloaded if missing
- MinIO will be updated to the latest binary if missing
- The runner will be left alone if already configured

### Save the MinIO credentials

The playbook prints the endpoint, access key, and bucket name at the end. Save
these as GitHub secrets:

| Secret | Value |
|--------|-------|
| `MINIO_ACCESS_KEY` | `minioadmin` (or whatever you set) |
| `MINIO_SECRET_KEY` | The password you chose above |

## 5. Configure Remaining CI Secrets

Go to **GitHub repo → Settings → Secrets and variables → Actions** and add:

| Secret | How to obtain |
|--------|---------------|
| `PROXMOX_API_TOKEN` | Proxmox UI → Datacenter → Permissions → API Tokens → Add. Format: `USER@realm!TOKENID=SECRET` |
| `SSH_PUBLIC_KEY` | Contents of `~/.ssh/id_rsa.pub` (the key injected into all Guests) |
| `PIHOLE_ADMIN_PASSWORD` | Choose a strong password for the Pi-hole web UI |
| `CLOUDFLARE_ORIGIN_CERT` | Cloudflare Origin CA certificate in PEM format |
| `CLOUDFLARE_ORIGIN_KEY` | Cloudflare Origin CA private key in PEM format |
| `LAMINAR_AUTH_SECRET` | Random Laminar session secret of at least 32 bytes |
| `LAMINAR_GITHUB_OAUTH_ID` | GitHub OAuth App client ID |
| `LAMINAR_GITHUB_OAUTH_SECRET` | GitHub OAuth App client secret |

For the Cloudflare, router, and GitHub OAuth configuration, see
[Reverse Proxy and Public HTTPS Access](reverse-proxy.md).

## 6. Initialize Terraform

The S3 backend (MinIO) needs AWS-style credentials. Export the same MinIO
access key and secret key from step 4:

```bash
cd terraform
export AWS_ACCESS_KEY_ID="minioadmin"
export AWS_SECRET_ACCESS_KEY="YOUR_MINIO_PASSWORD_FROM_STEP_4"
terraform init
```

If `terraform init` fails because the MinIO endpoint is unreachable, verify:
- MinIO service is running on Proxmox (`systemctl status minio`)
- Port 9000 is not blocked by Proxmox firewall (`iptables -L`)

## 7. First Apply (Infrastructure Only)

```bash
cd terraform
export TF_VAR_proxmox_api_token="YOUR_TOKEN_HERE"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
terraform apply
```

This creates:
- The LXCs defined in `config.yml`
- Network configuration with static IPs
- (The Debian 12 template was already downloaded in step 4)

## 8. Migrate Home Assistant Configuration

Before running Ansible for the first time, copy your existing Home Assistant
`/config` from the Raspberry Pi to the new LXC:

```bash
# From the Raspberry Pi, or any host with SSH to both:
rsync -avz --progress /config/ root@192.168.178.202:/opt/homeassistant/config/
```

## 9. Deploy Applications (Ansible)

Run the full Ansible playbook via the CI workflow:

1. Push a commit to `main` (or open a PR and merge it).
2. Go to **Actions → Terraform Apply + Ansible Deploy**.
3. Click **Run workflow** to trigger a manual apply.

Or run Ansible manually from the runner:

```bash
cd ansible
../scripts/generate-inventory.sh  # requires terraform output from step 7
ansible-playbook -i inventory.yml playbook.yml \
  --extra-vars "pihole_admin_password=YOUR_PASSWORD_HERE"
```

The reverse proxy and Laminar roles also require the environment variables
listed in [Reverse Proxy and Public HTTPS Access](reverse-proxy.md).

## 10. Verify

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
# On the Proxmox node:
mc rm local/terraform-state/homelab/terraform.tfstate.tflock --insecure --force
```

Or use the Ansible bootstrap playbook to ensure MinIO is healthy, then remove
the lock object from the MinIO console at `http://192.168.178.200:9001`.
