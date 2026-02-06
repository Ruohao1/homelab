# Homelab

Reproducible, VPN-only homelab with Proxmox, Terraform, and Ansible. Built bottom-up to keep the lab segmented, safe, and rebuildable.

## Principles

- Networking truth lives in the firewall/router config.
- Infrastructure truth lives in Terraform.
- Configuration truth lives in Ansible.
- No inbound exposure; access is via WireGuard only.

## Architecture

- Overview: `docs/architecture/overview.md`
- How it works: `docs/architecture/how-it-works.md`
- Diagram: `docs/architecture/homelab-network.png`

## Repo layout

- `docs/`: architecture docs
- `infra/terraform/`: provisioning stacks
- `infra/ansible/`: configuration management (dynamic inventory)
- `tools/`: diagram generator and assets

## Terraform stacks

- AWS WireGuard hub: `infra/terraform/stacks/aws-vpn-hub`
- Proxmox core: `infra/terraform/stacks/proxmox-core`

## Ansible

- Baseline hardening: `infra/ansible/playbooks/baseline.yml`
- Extra hardening: `infra/ansible/playbooks/hardening.yml`
- WireGuard config: `infra/ansible/playbooks/vpn-gateway.yml`

## State & secrets

- Terraform state should be remote and encrypted.
- Do not commit secrets to this repo.
