# Talos Linux Infrastructure

> **Planned**: Immutable, API-managed Kubernetes OS with zero SSH access.

## Why Talos?

| Feature | Traditional (Ubuntu/k3s) | Talos Linux |
|---------|--------------------------|-------------|
| SSH Access | ✅ Yes (attack surface) | ❌ None (API-only) |
| OS Updates | Manual/apt | Atomic A/B partition swap |
| Configuration | Scattered files | Single YAML machine config |
| Package Manager | apt/yum | ❌ None (immutable rootfs) |
| Attack Surface | Large | Minimal (just K8s components) |
| Drift | Possible | Impossible |

## Directory Structure

```
talos/
├── README.md              # This file
├── bare-metal/            # For homelab / physical servers
│   ├── controlplane.yaml  # Machine config (control plane)
│   ├── worker.yaml        # Machine config (worker nodes)
│   └── talosconfig        # Client config (generated)
│
└── hetzner-dedicated/     # For Hetzner Robot dedicated servers
    ├── main.tf            # Terraform for dedicated server provisioning
    ├── talos-image.yaml   # Custom Talos image config
    └── variables.tf       # Terraform variables
```

## Hetzner Options

| Server | Specs | Cost/month | Notes |
|--------|-------|------------|-------|
| **AX41-NVMe** | Ryzen 3600, 64GB, 2x512GB NVMe | €45 | Best value for homelab-style |
| **AX52** | Ryzen 5600X, 64GB, 2x1TB NVMe | €67 | More storage |
| **EX44** | Intel i5-13500, 64GB, 2x512GB NVMe | €53 | Intel alternative |

### Why Dedicated vs VPS for Talos?

- **VPS (Cloud)**: Can't easily boot custom ISO (Talos), limited to their images
- **Dedicated (Robot)**: Full IPMI/KVM access, boot any ISO, bare-metal performance

## Prerequisites

```bash
# Install talosctl
curl -sL https://talos.dev/install | sh

# Verify
talosctl version --client
```

## Quick Start (Planned)

```bash
# 1. Generate machine configs
talosctl gen config gitops-cluster https://<control-plane-ip>:6443 \
  --output-dir ./bare-metal

# 2. Apply to node (no SSH!)
talosctl apply-config --insecure \
  --nodes <node-ip> \
  --file ./bare-metal/controlplane.yaml

# 3. Bootstrap etcd on first control plane
talosctl bootstrap --nodes <control-plane-ip>

# 4. Get kubeconfig
talosctl kubeconfig --nodes <control-plane-ip>

# 5. Deploy ArgoCD (same as k3s!)
kubectl apply -f argocd/bootstrap.yaml
```

## Integration with GitOps

Talos machine configs can include inline manifests:

```yaml
# In controlplane.yaml
cluster:
  inlineManifests:
    - name: argocd-namespace
      contents: |
        apiVersion: v1
        kind: Namespace
        metadata:
          name: argocd
    - name: argocd-bootstrap
      contents: |
        # Bootstrap Application goes here
```

## Maintenance

```bash
# Upgrade Talos OS (atomic, rollback-safe)
talosctl upgrade --nodes <ip> \
  --image ghcr.io/siderolabs/installer:v1.6.0

# Upgrade Kubernetes
talosctl upgrade-k8s --nodes <ip> --to 1.29.0

# View logs (no SSH needed)
talosctl logs kubelet --nodes <ip>

# Interactive dashboard
talosctl dashboard --nodes <ip>
```

## Status

- [ ] Generate base machine configs
- [ ] Test on Hetzner dedicated server (AX41-NVMe)
- [ ] Document IPMI/KVM bootstrap process
- [ ] Add Terraform automation for Hetzner Robot API
- [ ] Integrate with existing ArgoCD bootstrap

## Resources

- [Talos Documentation](https://www.talos.dev/docs/)
- [Talos on Hetzner Guide](https://www.talos.dev/docs/v1.6/talos-guides/install/cloud-platforms/hetzner/)
- [Hetzner Robot API](https://robot.your-server.de/doc/webservice/en.html)
