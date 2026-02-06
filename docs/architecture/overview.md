# Architecture Overview

## Goal

Build a lab that mirrors real infrastructure for **DevOps/SRE + cloud-security**, while staying **non-exposed** (no inbound to home), **declarative**, and **disposable**.

Core rules:

- **Terraform is the authoritative source of truth** for infra definitions.
- **No inbound exposure** of homelab services to the public internet.
- **All access via VPN** (WireGuard in the cloud; homelab connects outbound).
- Assume nodes are disposable; **state and secrets are protected**.

See `docs/architecture/how-it-works.md` for the end-to-end flow and component interactions.

---

## Constraints

- Hardware:
  - **Always-on mini-PC**: Proxmox host for the “core” control plane + always-on services.
  - **Main computer**: burst capacity for experiments (attack VMs, heavy builds, short-lived clusters).
- Runtime:
  - Primary: **Docker + systemd** for simplicity and determinism.
  - Optional: **k3s** for “Kubernetes realism” (GitOps, policies, service mesh experiments).
- Cloud (minimal footprint):
  - Only for **VPN gateway**, **off-site backups**, **external attacker perspective**.
  - No long-running stateful workloads in cloud.

---

## Layered Architecture (boxes → arrows)

### 1) Hardware

- Mini-PC (always-on)
- Main PC (burst/experiments)
- Router/switch (existing home network)

### 2) Virtualization Layer (Proxmox on mini-PC)

- Proxmox provides:
  - VM/LXC lifecycle
  - isolated virtual networking (bridges/VLANs)
  - snapshots/rollback
- The Proxmox node is the “datacenter” boundary.

### 3) Provisioning / IaC Layer (Terraform)

Terraform responsibilities:

- Create and configure:
  - Proxmox VMs/LXCs (templates, sizing, networks)
  - DNS records (internal), firewall rules (where applicable)
  - Cloud resources (WireGuard VPS, object storage, backup credentials)
- Export inventory details for configuration management
- Manage **state**:
  - Stored securely (remote backend preferred)
  - Locked, versioned, backed up

Terraform does **not**:

- manage day-to-day app config drift inside machines (that’s “config mgmt” territory)
- replace your runtime orchestrator

### 4) Configuration Management (Ansible)

- Applies baseline and hardening on provisioned hosts
- Uses dynamic inventory sourced from Terraform state/outputs
- Groups hosts by role (e.g., `role_control`, `role_worker`) and site

### 5) Runtime Layer (Docker/systemd or k3s)

- Baseline runtime: Docker Compose + systemd units
- Optional runtime: k3s cluster (one or multiple nodes)
- Every service is deployed into a clearly defined **trust zone** and **network**.

### 6) Security & Observability Layer (cross-cutting)

- Identity + Secrets:
  - Password manager + optional Vault later
  - SSH keys, least privilege, no password SSH
- Network security:
  - segmentation (mgmt vs lab vs services)
  - default-deny policies between zones
- Observability:
  - centralized logs + metrics + alerting pipeline
  - “attacker perspective” monitoring from cloud VPS

---

## Logical Network Design (trust boundaries)

### Networks

1) **MGMT (Management)**

- Used for: Proxmox admin, SSH bastion, provisioning endpoints
- Access: only via VPN (WireGuard) + local admin LAN if needed
- Strongest controls (smallest blast radius)

1) **SERVICES (Internal services)**

- Used for: dashboards, internal apps (Vaultwarden, Nextcloud, etc.)
- Accessible:
  - from your VPN clients
  - optionally from a “jump” host
- Should not be reachable from LAB by default

1) **LAB (Attack/Defense playground)**

- Used for: vulnerable machines, malware sandboxing, CTF infra, security tooling
- Treat as hostile:
  - strict egress controls
  - no direct reach to MGMT
  - only controlled paths to logging/telemetry endpoints

1) **VPN Overlay**

- WireGuard in cloud is the hub
- Homelab initiates outbound tunnel to cloud
- Your devices connect to cloud, then route into homelab networks

### Routing rules (high-level)

- VPN clients → MGMT + SERVICES (allowed)
- LAB → SERVICES (deny by default; allow only telemetry/log shipping)
- LAB → MGMT (deny)
- SERVICES → MGMT (allow only what’s needed)
- Internet inbound → none to homelab (cloud VPS only)

---

## Diagram-ready Flow (boxes + arrows, no fluff)

**User device**
→ (WireGuard) → **Cloud VPN VPS**
→ (WireGuard) → **Homelab gateway VM/CT**
→ routes to:

- **MGMT net** → Proxmox UI / SSH bastion / Terraform runner
- **SERVICES net** → internal apps + observability stack
- **LAB net** → attack/defense targets (isolated)

**Backup flow**

- Services snapshots / data exports
→ (VPN or outbound HTTPS) → **Object storage (off-site)**

**External attacker perspective**

- Cloud VPS runs:
  - uptime checks
  - “what does the internet see?” scans of the VPS only
  - optional honeypot on the VPS (not on homelab)

---

## Component → Responsibility Mapping

### Proxmox

- compute + virtualization
- network bridges/VLANs (L2 separation)
- snapshots/rollback
- host firewall (optional, but keep rules simple)

### Terraform

- defines desired infrastructure state:
  - Proxmox VMs/LXCs (names, CPU/RAM/disk, NICs, networks)
  - cloud VPN VPS + firewall
  - backup resources and credentials wiring
- outputs inventory info (IP addresses, hostnames, service endpoints)

### Ansible

- applies baseline + hardening inside VMs/LXCs
- uses dynamic inventory from Terraform to avoid drift

### Runtime (Docker/systemd)

- deploys services inside VMs/LXCs
- service lifecycle:
  - systemd units, health checks, restart policies
  - Compose for multi-service stacks
- logs/metrics forwarding agents

### Runtime (k3s option)

- higher realism:
  - namespaces per trust zone or workload type
  - network policies, admission control, GitOps
- only after the baseline is stable (otherwise you build a cathedral on sand)

---

## Subnets and Hosts

The homelab is segmented by purpose and trust level. Each subnet has a clear role and an expected set of hosts.

### Management subnet (10.10.0.0/24)

- Purpose: control plane access only.
- Hosts: Proxmox admin, bastion/jumpbox, Terraform/Ansible control.
- Rules: VPN-only access; no inbound from other subnets.

### Observability subnet (10.20.0.0/24)

- Purpose: defensive telemetry that survives compromise elsewhere.
- Hosts: metrics, logs, alerting, IDS sensors.
- Rules: allow inbound telemetry from workloads/lab/k3s; minimal egress.

### Services subnet (10.30.0.0/24)

- Purpose: shared internal platform plumbing.
- Hosts: internal DNS, reverse proxy (VPN-only), PKI, NTP, registry mirror.
- Rules: allow DNS from all; deny access to mgmt.

### Workloads subnet (10.40.0.0/24)

- Purpose: stable internal applications.
- Hosts: Nextcloud, Jellyfin, Vaultwarden, app backends/DBs.
- Rules: can reach services + observability; never reach mgmt.

### Lab subnet (10.40.10.0/24)

- Purpose: intentionally unsafe targets and experiments.
- Hosts: DVWA/Juice Shop, exploit targets, sandboxes.
- Rules: deny access to mgmt; strict egress; allow only required telemetry.

### k3s-nodes subnet (10.40.20.0/24)

- Purpose: optional Kubernetes substrate.
- Hosts: k3s control-plane and workers.
- Rules: treat as hostile; restrict access to mgmt and services.

### Ephemeral subnet (10.40.30.0/24)

- Purpose: short-lived compute.
- Hosts: CI runners, scanners, throwaway VMs.
- Rules: deny access to mgmt; limited, task-specific egress.

### VPN overlay subnet (10.50.0.0/24)

- Purpose: remote access entry point only.
- Hosts: wg-hub (cloud), wg-gw (homelab), optional admin peers.
- Rules: VPN can reach mgmt; deny other subnets by default.

---

## Security Considerations (common failure modes)

- “VPN is up so I’m safe” is false:
  - VPN expands your trusted network. Compromise of a client = lateral movement risk.
- Flat networks:
  - if LAB can hit MGMT, you will eventually nuke your own control plane.
- Terraform state leakage:
  - state files often contain secrets, IPs, topology. Treat them like credentials.
- DNS and routing drift:
  - enforce one source of truth; avoid hand edits.
- Overcomplicated firewall rules:
  - complexity becomes a vulnerability and breaks reproducibility.

---

## Definitions

- **MGMT**: control plane / admin access network
- **SERVICES**: internal apps and observability
- **LAB**: hostile playground
- **VPN Overlay**: the only allowed remote access path
- **Disposable nodes**: rebuildable from templates + Terraform, without tears
