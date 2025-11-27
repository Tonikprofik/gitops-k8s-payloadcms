# =============================================================================
# Hetzner Cloud Infrastructure
# =============================================================================
#
# Provisions a cost-effective VPS on Hetzner Cloud with k3s pre-installed.
# Hetzner offers excellent price/performance for EU-based workloads.
#
# COST (Nov 2025, excl. VAT):
#   cx11  (2 vCPU, 4GB RAM):  €3.49/month ⭐ Cheapest shared
#   cax11 (2 vCPU, 4GB ARM):  €3.79/month (Ampere, if image supports ARM)
#   cx22  (2 vCPU, 4GB RAM):  €4.99/month (regular shared)
#   Compared to AWS t3.small: ~$15-20/month
#
# USAGE:
#   export TF_VAR_hcloud_token="your-api-token"
#   terraform init
#   terraform apply
#
# SECURITY NOTE:
#   - API token has full account access - treat it like a password
#   - SSH key is used for secure access (no password auth)
#   - Auto-shutdown cron limits exposure time
#
# =============================================================================

# Terraform provider configuration
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

# Hetzner API Token - passed via TF_VAR_hcloud_token environment variable
# Generate at: https://console.hetzner.cloud/ → Security → API Tokens
variable "hcloud_token" {
  description = "Hetzner Cloud API token with Read & Write permissions"
  type        = string
  sensitive   = true  # Prevents token from appearing in logs
}

# Path to your SSH public key
variable "ssh_public_key_path" {
  description = "Path to SSH public key for server access"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"  # Modern default; fallback to id_rsa.pub if needed
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "hcloud" {
  token = var.hcloud_token
}

# =============================================================================
# SSH Key
# =============================================================================
# Upload your public SSH key to Hetzner for secure server access.
# The private key stays on your machine, public key goes to the server.

resource "hcloud_ssh_key" "default" {
  name       = "gitops-demo-key"
  # Reads from SSH key path (configurable via var.ssh_public_key_path)
  # Generate if missing: ssh-keygen -t ed25519
  public_key = file(var.ssh_public_key_path)
}

# =============================================================================
# VPS Server
# =============================================================================
# Single node running k3s (lightweight Kubernetes).
# Cloud-init script installs k3s and ArgoCD on first boot.

resource "hcloud_server" "k3s_node" {
  name        = "gitops-demo-cluster"
  image       = "ubuntu-22.04"  # LTS release, well-supported

  # SERVER TYPE OPTIONS (Nov 2025 pricing):
  #   cx11  - €3.49/mo - 2 vCPU, 4GB RAM, 40GB NVMe (Cost-Optimized) ⭐
  #   cax11 - €3.79/mo - 2 vCPU ARM, 4GB RAM, 40GB NVMe (Ampere)
  #   cx22  - €4.99/mo - 2 vCPU, 4GB RAM, 40GB NVMe (Regular)
  #   cx32  - €5.49/mo - 4 vCPU, 8GB RAM, 80GB NVMe
  # k3s + PayloadCMS + Prometheus fits in 4GB RAM
  server_type = "cx11"

  # LOCATION: Nuremberg, Germany (EU)
  # Other options: fsn1 (Falkenstein), hel1 (Helsinki)
  # Choose based on latency requirements
  location    = "nbg1"

  # Attach SSH key for secure access (no password auth)
  ssh_keys    = [hcloud_ssh_key.default.id]

  # CLOUD-INIT: Bootstrap script run on first boot
  # See user_data.yml for k3s and ArgoCD installation
  user_data = file("${path.module}/user_data.yml")

  # Enable both IPv4 and IPv6 public networking
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  # Labels for organization and filtering in Hetzner console
  labels = {
    environment = "demo"
    project     = "gitops-payloadcms"
    managed_by  = "terraform"
  }
}

# =============================================================================
# Outputs
# =============================================================================
# Values printed after terraform apply and accessible via terraform output

# Public IP address of the server
output "public_ip" {
  description = "Public IPv4 address of the k3s node"
  value       = hcloud_server.k3s_node.ipv4_address
}

# Command to fetch kubeconfig from remote server
# Run this after server is ready to connect kubectl to the cluster
output "kubeconfig_command" {
  description = "Command to fetch kubeconfig from the k3s node"
  value       = "scp -o StrictHostKeyChecking=no root@${hcloud_server.k3s_node.ipv4_address}:/etc/rancher/k3s/k3s.yaml ./kubeconfig_hetzner && sed -i 's/127.0.0.1/${hcloud_server.k3s_node.ipv4_address}/g' ./kubeconfig_hetzner"
}
