# Homelab Infrastructure

IaC-managed Proxmox homelab. Single source of truth for compute, networking,
and applications.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Scope | Infrastructure (Proxmox Guests) + Applications (Ansible) |
| Guest type | Separate LXCs per application |
| Pi-hole | Native Debian LXC, bridged networking, static IP |
| Home Assistant | Native Debian LXC with Docker (preserves Pi setup) |
| IaC tools | Terraform for Guests, Ansible for Applications |
| Workflow | GitHub Actions, self-hosted runner on LAN |
| State | Terraform state in MinIO (S3-compatible) on LAN |
| Trigger | PR opens → plan; manual dispatch → apply |

## Repo Structure

```
.
├── config.yml              # Single source of truth (network, guests)
├── terraform/              # Proxmox Guest definitions
├── ansible/                # Application deployment
├── scripts/                # Config generation helpers
├── .github/workflows/      # CI workflows
└── CONTEXT.md              # Domain glossary
```

## Prerequisites

See [docs/setup.md](docs/setup.md) for the full bootstrap procedure.

In short:
1. Proxmox node at `192.168.178.200`
2. MinIO bucket `terraform-state` on the LAN (script provided)
3. GitHub Actions self-hosted runner (script provided)
4. Five CI secrets configured in GitHub

## Open Issues / Risks

1. **Config migration is manual.** The `rsync` step from the Pi to the HA LXC
   must be performed once before Home Assistant starts.
