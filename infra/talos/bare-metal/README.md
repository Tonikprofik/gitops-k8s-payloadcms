# Talos Machine Config Templates - Bare Metal

This directory contains machine configuration templates for bare-metal Talos clusters.

## Files

- `controlplane.yaml` - Template for control plane nodes
- `worker.yaml` - Template for worker nodes  
- `talosconfig` - Generated client config (after `talosctl gen config`)

## Generate Configs

```bash
# Replace with your control plane IP/VIP
talosctl gen config my-cluster https://192.168.1.100:6443 \
  --output-dir ./ \
  --with-docs=false \
  --with-examples=false

# This creates:
# - controlplane.yaml
# - worker.yaml
# - talosconfig
```

## Apply to Nodes

```bash
# Control plane (first node)
talosctl apply-config --insecure \
  --nodes 192.168.1.100 \
  --file controlplane.yaml

# Workers
talosctl apply-config --insecure \
  --nodes 192.168.1.101 \
  --file worker.yaml
```

## Bootstrap

```bash
# Only on first control plane, only once
talosctl bootstrap --nodes 192.168.1.100 --talosconfig ./talosconfig

# Get kubeconfig
talosctl kubeconfig --nodes 192.168.1.100 --talosconfig ./talosconfig
```
