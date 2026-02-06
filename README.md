# Hybrid Homelab – Secure & Reproducible Infrastructure

This repository documents and defines a **production-inspired homelab** designed to practice **DevOps, SRE, and cloud-security workflows** under strict security and reproducibility constraints.

---

## Why This Project Exists

This project reflects how I personally learn best: by operating real systems with real consequences. I built this homelab as a deliberate learning environment where design decisions are tested under realistic constraints.

Rather than studying DevOps, SRE, and cloud security concepts in isolation, this project forces me to design, operate, break, and rebuild a real system. Every architectural decision is something I expect to justify, automate, and recover from.

I intentionally alternate between defensive and offensive roles. The same infrastructure is used to deploy services, monitor them, attack them, detect compromise, and recover from failure. Automation applies not only to provisioning, but also to teardown, rebuilds, and remediation.

Failure is part of the workflow. Clean, predictable recovery is the objective.

The goals of this project are to:

- Design and operate infrastructure using **Terraform and Ansible** as the source of truth
- Enforce **explicit trust boundaries** and least-privilege networking
- Practice **defensive monitoring, detection, and alerting**
- Launch **controlled attacks** against my own services and lab environments
- Automate **recovery, rebuilds, and configuration drift correction**
- Treat compromise and failure as normal operating conditions

This homelab is intentionally designed to feel closer to a small production environment than a guided lab or tutorial.

---

## Constraints & Scope

I run this homelab alone, with limited hardware and a minimal cloud footprint, and I treat those constraints as part of the learning process rather than a limitation. The environment is intentionally designed to be reproducible, observable, and safe to tear down and rebuild repeatedly.

### Hardware
- **1× mini-PC** (always on) running **Proxmox**
- **2× user devices**
  - Laptop (administration)
  - Phone (VPN client)

### Cloud
- **1× minimal AWS EC2 instance**
  - Used **only** as a WireGuard VPN gateway
- No long-running or stateful cloud workloads

If this architecture works here, it scales conceptually to larger environments.

---

## Core Design Principles

- **No inbound exposure**
  - The homelab has **zero open inbound ports**
- **VPN-first access**
  - WireGuard is the **only entry point**
- **Clear trust tiers**
  - Management ≠ services ≠ workloads ≠ labs
- **Declarative infrastructure**
  - Terraform defines *what exists*
  - Ansible defines *how it is configured*
- **Disposable mindset**
  - VMs and nodes are replaceable
  - Persistent data is explicitly isolated

---

## Tooling Stack

### Virtualization
- **Proxmox** – bare-metal hypervisor

### Infrastructure as Code
- **Terraform**
  - Proxmox VMs and networks
  - Cloud VPN gateway (AWS EC2)
- **Ansible**
  - OS hardening
  - Service configuration
  - Post-provisioning setup

### Networking & Access
- **WireGuard**
  - Cloud-hosted hub
  - Homelab gateway peer
  - Laptop / phone peers
- **Firewall / Router VM**
  - Default gateway for all subnets
  - NAT, routing, east–west filtering

### Platform Services
- Internal DNS (Unbound / CoreDNS)
- Reverse proxy (VPN-only ingress)
- Observability stack:
  - Prometheus
  - Grafana
  - Loki / ELK
- Optional lightweight Kubernetes (k3s)

---

## End-to-End Workflow

1. **Define Infrastructure**
   - Terraform defines cloud, networks, and VMs
   - Terraform state is the single source of truth

2. **Provision**
   - Proxmox VMs are created
   - Firewall/router VM is deployed
   - Networks and routing are established

3. **Configure**
   - Ansible hardens hosts
   - WireGuard peers are configured
   - Core services (DNS, proxy, observability) are deployed

4. **Access**
   - Laptop / phone → WireGuard → cloud hub → homelab gateway
   - Management access via bastion
   - Services exposed only through VPN-only reverse proxy

5. **Operate & Rebuild**
   - Nodes can be destroyed and recreated
   - Logs and metrics remain available
   - Compromise is contained by subnet boundaries

---

## Network Architecture

![Homelab network overview](./assets/homelab-network.png)

### Cloud

**VPN Overlay – `10.50.0.0/24`**
- WireGuard tunnel endpoints
- Peers:
  - `10.50.0.1`  – wg-hub (cloud)
  - `10.50.0.10` – wg-gw (homelab)
  - `10.50.0.20` – admin-laptop (optional)

**Cloud-only Subnet – `10.60.0.0/24`**
- Disposable external perspective
- Use cases:
  - Attacker simulation
  - Off-site backup relay
  - Internet-side testing

---

### Homelab (Proxmox)

**Management Subnet – `10.10.0.0/24` (Highest Trust)**
- Proxmox UI / SSH
- Bastion / jumpbox
- Terraform / Ansible control plane
- Reachable only via VPN

**Observability Subnet – `10.20.0.0/24`**
- Logs, metrics, alerting
- Designed to survive compromise elsewhere
- Minimal inbound access

**Services Subnet – `10.30.0.0/24`**
- Internal shared services:
  - DNS resolver
  - Reverse proxy (VPN-only edge)
  - ACME / internal PKI
  - Optional mirrors (NTP, registry)

**Compute Block – `10.40.0.0/20` (Untrusted by Default)**

- **Workloads – `10.40.0.0/24`**
  - Semi-stable applications
  - Nextcloud, Jellyfin, Vaultwarden
  - Application backends and databases

- **Lab – `10.40.10.0/24`**
  - Intentionally vulnerable systems
  - Red-team targets
  - Malware / exploit testing

- **k3s Nodes – `10.40.20.0/24`**
  - Optional Kubernetes substrate
  - Isolated from management plane

- **Ephemeral – `10.40.30.0/24`**
  - CI runners
  - Scanners and fuzzers
  - Short-lived test VMs

---

## Security Model Summary

- No service is reachable without VPN
- Management plane is isolated and minimal
- East–west traffic is explicitly filtered
- Lab environments are treated as hostile
- Observability remains reachable during incidents

If a subnet is compromised, the design question becomes:
> *Why was this subnet allowed to talk to anything important?*

That is intentional.

---

## What This Lab Is (and Is Not)

This lab **is**:
- A hands-on learning environment
- A place to practice production-grade design under constraints
- A platform for experimenting with security, observability, and automation

This lab is **not**:
- A fully hardened production environment
- A high-availability or multi-datacenter setup
- A showcase of uptime over correctness

Learning, iteration, and controlled failure are explicitly part of the design.

---

## Status

This repository is actively evolving.  
Design decisions prioritize **clarity, safety, and realism** over convenience.

---

## License

Personal learning project.  
No warranty. No shortcuts.

