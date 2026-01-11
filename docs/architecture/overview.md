# Architecture Overview

## Goal

Build a lab that mirrors real infrastructure for **DevOps/SRE + cloud-security**, while staying **non-exposed** (no inbound to home), **declarative**, and **disposable**.

Core rules:

- **Terraform is the authoritative source of truth** for infra definitions.
- **No inbound exposure** of homelab services to the public internet.
- **All access via VPN** (WireGuard in the cloud; homelab connects outbound).
- Assume nodes are disposable; **state and secrets are protected**.

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
- Manage **state**:
  - Stored securely (remote backend preferred)
  - Locked, versioned, backed up

Terraform does **not**:

- manage day-to-day app config drift inside machines (that’s “config mgmt” territory)
- replace your runtime orchestrator

### 4) Runtime Layer (Docker/systemd or k3s)

- Baseline runtime: Docker Compose + systemd units
- Optional runtime: k3s cluster (one or multiple nodes)
- Every service is deployed into a clearly defined **trust zone** and **network**.

### 5) Security & Observability Layer (cross-cutting)

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

## Build Order (opinionated)

### Phase 0 — Foundations (do first)

1) Cloud VPS with WireGuard (hub)
2) Homelab connects outbound to cloud (site-to-site WG)
3) MGMT network + bastion/jump host reachable only via VPN
4) Terraform state strategy (remote backend, locking, backups)

### Phase 1 — Core Platform

1) Proxmox “golden templates” (cloud-init ready)
2) Terraform-managed VM lifecycle for:
   - gateway/jump host
   - DNS (internal) + reverse proxy (internal only)
3) Baseline observability:
   - syslog/agent + minimal dashboarding

### Phase 2 — Security Lab + Telemetry

1) LAB network + “victim” VMs
2) Egress controls (deny-all by default, allow only necessary)
3) SIEM pipeline (log collection → parsing → storage → visualization)
4) Continuous scanning from inside (and from cloud for the VPS only)

### Phase 3 — Optional k3s

- Only after:
  - networking is clean
  - VPN and segmentation are proven
  - backups are real and tested

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
