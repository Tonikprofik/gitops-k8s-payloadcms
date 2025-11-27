# Quick Start Guide

Get the entire stack running locally in **5 minutes**.

## Prerequisites

### Required Tools

```bash
# Docker (container runtime)
# Install: https://docs.docker.com/get-docker/

# kubectl (Kubernetes CLI)
# Install: https://kubernetes.io/docs/tasks/tools/

# k3d (k3s in Docker - local Kubernetes)
# Install:
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
# Or on macOS:
brew install k3d

# Optional: Terraform (for cloud deployment)
# Install: https://developer.hashicorp.com/terraform/downloads
```

### Verify Installation

```bash
docker --version        # Docker version 24.x+
kubectl version --client # Client Version: v1.28+
k3d version             # k3d version v5.x
```

## Local Development

### 1. Clone the Repository

```bash
git clone https://github.com/Tonikprofik/gitops-k8s-payloadcms.git
cd gitops-k8s-payloadcms
```

### 2. Bootstrap the Cluster

```bash
make local-up
```

This command:
1. Creates a k3d cluster named `demo-cluster`
2. Exposes port 8080 for ingress
3. Installs ArgoCD
4. Applies the bootstrap Application (triggers GitOps sync)

### 3. Access ArgoCD UI

```bash
# In a new terminal, start port-forward
make port-forward-argocd
```

Open https://localhost:8080 in your browser.

**Credentials:**
- Username: `admin`
- Password: Run `make argocd-password`

### 4. Watch GitOps Magic

In the ArgoCD UI, you'll see:
1. **bootstrap** app → Synced
2. **observability-stack** app → Syncing (Prometheus, Loki)
3. **payload-cms** app → Syncing (after observability is healthy)

### 5. Access Applications

**Grafana (Metrics & Logs):**
```bash
make port-forward-grafana
# Open http://localhost:3000
# Login: admin / admin
```

**PayloadCMS:**
```bash
# Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
127.0.0.1 payload.localhost

# Access at http://payload.localhost:8080
```

## Cloud Deployment (Hetzner)

### 1. Get Hetzner API Token

1. Create account at https://console.hetzner.cloud/
2. Go to Security → API Tokens
3. Generate new token with Read & Write permissions

### 2. Export Token

```bash
export TF_VAR_hcloud_token="your-token-here"
```

### 3. Provision Infrastructure

```bash
make hetzner-up
```

This runs Terraform to:
1. Create SSH key in Hetzner
2. Provision cpx11 VPS (2 vCPU, 2GB RAM, ~€4/month)
3. Install k3s via cloud-init
4. Install ArgoCD
5. Set auto-shutdown cron (cost safety net)

### 4. Connect to Cluster

```bash
make hetzner-kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig_hetzner
```

### 5. Apply Bootstrap

```bash
kubectl apply -f argocd/bootstrap.yaml
```

### 6. Access ArgoCD

```bash
# Get node IP
cd infra/hetzner && terraform output public_ip

# Port-forward (or use NodePort/Ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 7. Cleanup (Important!)

**Don't forget to destroy resources when done:**

```bash
make hetzner-destroy
```

This deletes the VPS and SSH key, stopping all billing.

## Troubleshooting

### Pod Stuck in Pending

```bash
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
```

Common causes:
- Insufficient resources → Scale down replicas or increase node size
- PVC not bound → Check StorageClass

### ArgoCD Sync Failed

```bash
kubectl logs -n argocd deployment/argocd-application-controller
```

Common causes:
- Invalid YAML → Check syntax
- Repository not accessible → Verify Git URL
- Resource conflict → Check for duplicate names

### Grafana Not Loading

```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### PayloadCMS Not Starting

```bash
kubectl logs -n payload deployment/payload-cms
kubectl describe pod -n payload -l app=payload-cms
```

Check:
- Database connectivity (DATABASE_URI secret)
- Image pull (check image name and registry access)

## Next Steps

1. **Explore the ArgoCD UI** - Click on apps to see resource trees
2. **Make a Git Change** - Edit a manifest, push, watch ArgoCD sync
3. **Check Grafana Dashboards** - Explore pre-built Kubernetes dashboards
4. **View Logs in Grafana** - Use Explore → Loki data source
5. **Read the Architecture Docs** - [ARCHITECTURE.md](./ARCHITECTURE.md)

## Common Commands Reference

```bash
# Cluster Management
make local-up              # Create local cluster
make local-down            # Destroy local cluster

# Cloud Management
make hetzner-up            # Provision Hetzner VPS
make hetzner-destroy       # Destroy Hetzner VPS

# Access
make argocd-password       # Get ArgoCD admin password
make port-forward-argocd   # Forward ArgoCD to localhost:8080
make port-forward-grafana  # Forward Grafana to localhost:3000

# kubectl shortcuts
kubectl get pods -A                    # All pods
kubectl get applications -n argocd     # ArgoCD apps
kubectl logs -f deployment/X -n Y      # Follow logs
```

---

## ⚠️ Common Gotchas

Issues you'll hit and how to fix them.

### 1. `/etc/hosts` Entry Required (Local)

PayloadCMS Ingress expects `payload.localhost`. Without this, you get "connection refused".

```bash
# Linux/macOS: Add to /etc/hosts
echo "127.0.0.1 payload.localhost" | sudo tee -a /etc/hosts

# Windows: Add to C:\Windows\System32\drivers\etc\hosts (as Admin)
127.0.0.1 payload.localhost
```

### 2. Port 8080 Already in Use

```bash
# Error: port 8080 is already allocated
# Fix: Kill whatever is using it
lsof -i :8080  # Find PID
kill -9 <PID>

# Or change k3d port in scripts/bootstrap.sh:
# -p "8081:80@loadbalancer"
```

### 3. SSH Key Assumption (Hetzner)

Terraform expects `~/.ssh/id_rsa.pub` to exist.

```bash
# If you don't have SSH keys:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Then update infra/hetzner/main.tf:
public_key = file("~/.ssh/id_ed25519.pub")
```

### 4. Auto-Shutdown (Hetzner)

The Hetzner VPS has a cron job that shuts it down after 2 hours. This is a cost safety net.

```bash
# To disable (if you need longer uptime):
ssh root@<ip> "crontab -r"

# Or edit infra/hetzner/user_data.yml before provisioning
```

### 5. PayloadCMS Image Must Be Built

The demo uses `ghcr.io/tonikprofik/payload-cms:latest`. You need to build and push your own image.

```bash
# From your PayloadCMS repo (with Dockerfile):
docker build -t ghcr.io/<your-username>/payload-cms:latest .
docker push ghcr.io/<your-username>/payload-cms:latest

# Then update apps/payload-cms/deployment.yaml
```

### 6. Grafana Default Password

```bash
# Default: admin / admin
# You'll be prompted to change it on first login
# For production, set via Helm values:
grafana:
  adminPassword: <sealed-secret-value>
```

### 7. Loki Logs Lost on Restart

Demo Loki has no persistence. Logs disappear when pod restarts.

```yaml
# Fix in apps/observability/values-loki.yaml:
loki:
  persistence:
    enabled: true
    size: 10Gi
```

### 8. Node.js Version Mismatch

Your PayloadCMS needs Node 22.17. Ensure Dockerfile matches:

```dockerfile
# Correct (from your Dockerfile):
FROM node:22.17.0-alpine AS base

# Wrong (don't use older versions):
FROM node:20-alpine  # PayloadCMS 3.59 needs Node 22
```

---

## ✅ Production Checklist

Before deploying to Hetzner (or any cloud), verify these items.

### Secrets & Configuration

- [ ] Replace `secretGenerator` with SealedSecrets or External Secrets
- [ ] Generate strong `PAYLOAD_SECRET` (32+ random bytes)
- [ ] Generate strong `POSTGRES_PASSWORD` (20+ chars, no special chars for URI)
- [ ] Set `NEXT_PUBLIC_SERVER_URL` to your actual domain
- [ ] Configure `RESEND_API_KEY` for email (if using forms)

### Infrastructure

- [ ] Remove auto-shutdown cron (or extend to 24h)
- [ ] Add TLS with cert-manager + Let's Encrypt
- [ ] Configure DNS records (A record → server IP)
- [ ] Set up PostgreSQL backups (CronJob or managed DB)
- [ ] Add resource limits to all Deployments

### Security

- [ ] Restrict ArgoCD RBAC with AppProject
- [ ] Add NetworkPolicies (deny-all default)
- [ ] Enable Pod Security Standards (restricted)
- [ ] Use image digests instead of `:latest` tags
- [ ] Rotate all secrets quarterly

### Observability

- [ ] Enable Loki persistence
- [ ] Configure Prometheus retention (default 15d)
- [ ] Set up alerting (PagerDuty, Slack, email)
- [ ] Create PayloadCMS-specific Grafana dashboard

### Image Build

```bash
# Build with immutable tag:
docker build -t ghcr.io/<user>/payload-cms:$(git rev-parse --short HEAD) .
docker push ghcr.io/<user>/payload-cms:$(git rev-parse --short HEAD)

# Update deployment.yaml with SHA:
image: ghcr.io/<user>/payload-cms@sha256:<digest>
```

---

## 🐘 PostgreSQL Quick Reference

### Connection Strings

```bash
# Local (via kubectl port-forward):
kubectl port-forward svc/postgres -n payload 5432:5432
psql postgres://postgres:password@localhost:5432/payload

# From within cluster:
postgres://postgres:password@postgres.payload.svc.cluster.local:5432/payload
```

### Common Operations

```bash
# Exec into postgres pod:
kubectl exec -it postgres-0 -n payload -- psql -U postgres -d payload

# Backup database:
kubectl exec -it postgres-0 -n payload -- pg_dump -U postgres payload > backup.sql

# Restore database:
cat backup.sql | kubectl exec -i postgres-0 -n payload -- psql -U postgres -d payload
```

### Check Database Health

```bash
kubectl exec -it postgres-0 -n payload -- pg_isready -U postgres
# /var/run/postgresql:5432 - accepting connections
```
