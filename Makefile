# =============================================================================
# ArgoCD PayloadCMS - GitOps Reference Architecture
# =============================================================================
#
# Makefile for managing local and cloud Kubernetes environments.
#
# QUICK START:
#   make local-up        # Create local cluster + install everything
#   make argocd-password # Get ArgoCD admin password
#   make port-forward-argocd  # Access ArgoCD UI at https://localhost:8080
#
# =============================================================================

.PHONY: local-up local-down hetzner-up hetzner-down hetzner-kubeconfig argocd-password port-forward-argocd port-forward-grafana

# =============================================================================
# Local Development (k3d)
# =============================================================================
# Uses k3d (k3s in Docker) for fast, lightweight local Kubernetes.
# No VM required - just Docker.

# Create local cluster and bootstrap GitOps
local-up:
	@echo "🚀 Bootstrapping Local Environment..."
	./scripts/bootstrap.sh

# Destroy local cluster completely
local-down:
	@echo "💥 Destroying Local Environment..."
	k3d cluster delete demo-cluster

# =============================================================================
# Remote Production (Hetzner Cloud)
# =============================================================================
# Cost-effective cloud deployment on Hetzner VPS.
# Requires: export TF_VAR_hcloud_token="your-token"

# Provision Hetzner VPS with k3s via Terraform
hetzner-up:
	@echo "☁️  Provisioning Hetzner Cloud Infrastructure..."
	cd infra/hetzner && terraform init && terraform apply -auto-approve

# Fetch kubeconfig from remote k3s node
hetzner-kubeconfig:
	@echo "🔑 Fetching Kubeconfig..."
	$(shell cd infra/hetzner && terraform output -raw kubeconfig_command)
	@echo "Run: export KUBECONFIG=$(PWD)/kubeconfig_hetzner"

# Destroy cloud infrastructure (SAVES MONEY!)
hetzner-destroy:
	@echo "💸 Destroying Hetzner Infrastructure..."
	cd infra/hetzner && terraform destroy -auto-approve
	rm -f kubeconfig_hetzner

# =============================================================================
# Utilities
# =============================================================================
# Helper commands for accessing services

# Get ArgoCD initial admin password
argocd-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo ""

# Port-forward ArgoCD UI to localhost:8080
# Access at: https://localhost:8080 (accept self-signed cert warning)
port-forward-argocd:
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# Port-forward Grafana to localhost:3000
# Access at: http://localhost:3000 (admin/admin)
port-forward-grafana:
	kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
