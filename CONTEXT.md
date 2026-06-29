# Homelab Infrastructure

Single source of truth for compute, networking, and applications in a Proxmox-based homelab.

## Language

**Node**:
A physical Proxmox host managed by this repository.
_Avoid_: Server, host, hypervisor

**Guest**:
A virtualized workload unit on a Node — either a VM or an LXC.
_Avoid_: Instance, container (when ambiguous), VM (when LXC is also possible)

**LXC**:
A Linux container managed by Proxmox's Container Toolkit (pct).
_Avoid_: Container (without qualification), Docker container

**Template**:
A disk image stored on Proxmox storage, used to create an LXC Guest.
_Avoid_: Image (without qualification), ISO

**Application**:
A service deployed onto a Guest (e.g., pi-hole, Home Assistant).
_Avoid_: App, workload (when referring to the user-facing service)

**Workload**:
The combination of a Guest and the Application(s) running on it.
_Avoid_: Stack, deployment
