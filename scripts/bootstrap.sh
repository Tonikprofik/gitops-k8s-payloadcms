#!/bin/bash
# =============================================================================
# Local Development Bootstrap Script
# =============================================================================
#
# This script creates a complete local Kubernetes environment with:
#   1. k3d cluster (k3s in Docker)
#   2. ArgoCD (GitOps controller)
#   3. Bootstrap application (triggers GitOps sync)
#
# PREREQUISITES:
#   - Docker running
#   - kubectl installed
#   - k3d installed (curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash)
#
# USAGE:
#   ./scripts/bootstrap.sh
#   # Or via Make:
#   make local-up
#
# =============================================================================

set -e  # Exit immediately if any command fails

# Colors for pretty output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting GitOps Reference Architecture Bootstrap...${NC}"

# =============================================================================
# 1. Create K3D Cluster
# =============================================================================
# K3D runs K3s inside Docker containers, providing:
#   - Fast cluster creation/deletion (~30 seconds)
#   - No VM overhead (uses Docker containers)
#   - Port mapping for local access
#   - Multiple worker nodes for testing
# =============================================================================

if k3d cluster list | grep -q "demo-cluster"; then
    echo -e "${YELLOW}Cluster 'demo-cluster' already exists. Skipping creation.${NC}"
else
    echo "Creating k3d cluster 'demo-cluster'..."
    k3d cluster create demo-cluster \
        --api-port 6550 \
        -p "8080:80@loadbalancer" \
        --agents 2
    # --api-port 6550: Kubernetes API available on localhost:6550
    # -p "8080:80@loadbalancer": Map host port 8080 to cluster's ingress (port 80)
    # --agents 2: Create 2 worker nodes (simulates multi-node cluster)
fi

# =============================================================================
# 2. Create Namespaces
# =============================================================================
# Pre-create namespaces to avoid race conditions during ArgoCD sync.
# The --dry-run=client | kubectl apply pattern is idempotent (safe to re-run).
# =============================================================================

echo "Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace payload --dry-run=client -o yaml | kubectl apply -f -

# =============================================================================
# 3. Install ArgoCD
# =============================================================================
# ArgoCD is installed from official manifests.
# This creates:
#   - argocd-server (UI and API)
#   - argocd-repo-server (Git operations)
#   - argocd-application-controller (sync engine)
#   - argocd-dex-server (SSO, optional)
#   - argocd-redis (caching)
# =============================================================================

echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for the ArgoCD server to be ready before applying applications
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# =============================================================================
# 4. Apply Bootstrap Application
# =============================================================================
# This is the "App of Apps" pattern:
#   - One application (bootstrap) manages all other applications
#   - ArgoCD watches argocd/applications/ directory
#   - Adding/removing YAML files automatically adds/removes apps
# =============================================================================

echo "Applying Bootstrap Application..."
kubectl apply -f argocd/bootstrap.yaml

# =============================================================================
# Success Message
# =============================================================================

echo -e "${GREEN}Bootstrap Complete!${NC}"
echo "------------------------------------------------"
echo "ArgoCD UI: https://localhost:8080"
echo "Username: admin"
echo "Password: (run: make argocd-password)"
echo ""
echo "Grafana: http://localhost:3000 (after port-forward)"
echo "Username: admin, Password: admin"
echo ""
echo "PayloadCMS: http://payload.localhost:8080"
echo "(Add '127.0.0.1 payload.localhost' to /etc/hosts)"
echo "------------------------------------------------"
