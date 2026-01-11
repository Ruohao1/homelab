# Homelab

## Goals
- Proxmox on always-on mini-PC
- Terraform is the source of truth for infra
- No inbound exposure; access via WireGuard (cloud gateway)
- Disposable nodes; protected state (backups + secrets)

## Architecture
See: docs/architecture/overview.md

## Quickstart (high level)
1) Provision cloud VPN gateway (Terraform)
2) Connect homelab outbound to VPN
3) Provision Proxmox VMs/LXCs (Terraform)
4) Configure baseline + hardening (Ansible)
5) Deploy runtime workloads (Docker or k3s)

## Repo map
- docs/: architecture, runbooks, ADRs
- infra/terraform/: provisioning (Proxmox + cloud)
- infra/ansible/: configuration management
- platform/: k3s manifests or docker-compose stacks
- security/: threat model, policies, audits
- ops/: backups/monitoring/logging

## State & secrets
- Terraform state: remote (encrypted)
- Secrets: NOT in git. See security/secrets/README.md
