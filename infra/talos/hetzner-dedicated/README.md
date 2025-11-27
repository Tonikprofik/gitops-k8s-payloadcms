# Talos on Hetzner Dedicated Servers

Deploy Talos Linux to Hetzner Robot dedicated servers via Terraform + IPMI.

## Overview

Unlike Hetzner Cloud VPS, dedicated servers (Robot) allow:
- Custom ISO boot (Talos installer)
- IPMI/KVM access for initial setup
- Bare-metal performance
- Full control over hardware

## Recommended Servers

| Model | Specs | €/month | Use Case |
|-------|-------|---------|----------|
| AX41-NVMe | Ryzen 3600, 64GB, 2x512GB | €45 | Single-node cluster |
| AX52 | Ryzen 5600X, 64GB, 2x1TB | €67 | Storage-heavy |
| 2x AX41 | (HA setup) | €90 | Production HA |

## Prerequisites

1. Hetzner Robot account with dedicated server
2. Robot API credentials (webservice user)
3. `talosctl` installed locally

## Workflow

### 1. Order Server

Via Hetzner Robot console or API.

### 2. Boot Talos ISO

```bash
# Use Hetzner's installimage to write Talos to disk
# Or mount Talos ISO via KVM console
```

### 3. Apply Machine Config

```bash
# Generate config
talosctl gen config hetzner-cluster https://<server-ip>:6443

# Apply (server must be booted into Talos)
talosctl apply-config --insecure \
  --nodes <server-ip> \
  --file controlplane.yaml
```

### 4. Bootstrap

```bash
talosctl bootstrap --nodes <server-ip>
talosctl kubeconfig --nodes <server-ip>
```

## Terraform (Planned)

```hcl
# Uses Hetzner Robot API for:
# - Server provisioning
# - Rescue boot for Talos install
# - Firewall rules
```

## Files

- `main.tf` - Terraform configuration (TODO)
- `variables.tf` - Input variables (TODO)
- `talos-image.yaml` - Custom Talos image config (optional)
