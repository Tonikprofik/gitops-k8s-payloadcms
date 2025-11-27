# ArgoCD PayloadCMS GitOps Platform

> **GitOps driven Kubernetes platform**  patterns for deploying a PayloadCMS (TypeScript/React/Next.js) headless CMS with full observability stack.

[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-blue)](https://argo-cd.readthedocs.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s%20%7C%20k3d-326CE5)](https://k3s.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC)](https://www.terraform.io/)

## 🎯 What This Project Demonstrates

| Skill | Implementation |
|-------|----------------|
| **GitOps** | ArgoCD App-of-Apps pattern with automated sync |
| **Kubernetes** | Deployments, StatefulSets, Services, Ingress, Kustomize |
| **Infrastructure as Code** | Terraform for Hetzner Cloud VPS provisioning |
| **Observability** | Prometheus + Grafana (metrics), Loki (logs) |
| **Local Development** | k3d cluster with reproducible bootstrap |
| **Cost Optimization** | Auto-shutdown for cloud resources, lightweight k3s |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Git Repository                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ argocd/         │  │ apps/           │  │ infra/          │  │
│  │ bootstrap.yaml  │  │ payload-cms/    │  │ hetzner/        │  │
│  │ applications/   │  │ observability/  │  │ (Terraform)     │  │
│  └────────┬────────┘  └────────┬────────┘  └─────────────────┘  │
└───────────┼────────────────────┼────────────────────────────────┘
            │                    │
            ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ArgoCD (GitOps Controller)                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Bootstrap App → Watches argocd/applications/            │   │
│  │                                                          │   │
│  │  ┌──────────────────┐   ┌──────────────────────────┐    │   │
│  │  │ observability.yaml│   │ payload-cms.yaml        │    │   │
│  │  │ sync-wave: -1     │   │ sync-wave: 1            │    │   │
│  │  │ (deploy first)    │   │ (deploy after monitoring)│    │   │
│  │  └──────────────────┘   └──────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
            │                              │
            ▼                              ▼
┌──────────────────────────┐  ┌──────────────────────────────────┐
│   monitoring namespace   │  │       payload namespace          │
│  ┌────────────────────┐  │  │  ┌─────────────────────────────┐ │
│  │ Prometheus         │  │  │  │ PayloadCMS Deployment       │ │
│  │ Grafana            │  │  │  │ (TypeScript/React/Next.js)  │ │
│  │ Loki + Promtail    │  │  │  └─────────────────────────────┘ │
│  └────────────────────┘  │  │  ┌─────────────────────────────┐ │
└──────────────────────────┘  │  │ PostgreSQL StatefulSet      │ │
                              │  │ (persistent storage)         │ │
                              │  └─────────────────────────────┘ │
                              └──────────────────────────────────┘
```

## 📁 Repository Structure

```
.
├── argocd/
│   ├── bootstrap.yaml           # 🚀 Single entrypoint (App-of-Apps root)
│   └── applications/
│       ├── observability.yaml   # Prometheus + Loki stack
│       └── payload-cms.yaml     # PayloadCMS application
│
├── apps/
│   ├── observability/           # Helm charts via Kustomize
│   │   ├── kustomization.yaml   # Orchestrates Prometheus + Loki
│   │   ├── values-prometheus.yaml
│   │   └── values-loki.yaml
│   │
│   └── payload-cms/             # Raw Kubernetes manifests
│       ├── kustomization.yaml   # Aggregates all resources
│       ├── deployment.yaml      # PayloadCMS container
│       ├── postgres.yaml        # Database StatefulSet
│       ├── service.yaml         # ClusterIP service
│       └── ingress.yaml         # Traefik ingress rule
│
├── infra/
│   ├── hetzner/                 # Terraform for cloud deployment
│   │   ├── main.tf              # VPS + k3s provisioning
│   │   └── user_data.yml        # cloud-init script
│   └── aws/                     # AWS EKS (planned, not yet implemented)
│       └── README.md
│
├── scripts/
│   └── bootstrap.sh             # Local k3d cluster setup
│
├── pubdocs/                     # 📖 Deep-dive documentation
│   ├── ARCHITECTURE.md
│   └── QUICKSTART.md
│
└── Makefile                     # Developer commands
```

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [k3d](https://k3d.io/) (for local development)
- [Terraform](https://www.terraform.io/) (for cloud deployment)

### Local Development (5 minutes)

```bash
# 1. Clone and bootstrap
git clone https://github.com/Tonikprofik/gitops-k8s-payloadcms.git
cd gitops-k8s-payloadcms
make local-up

# 2. Access ArgoCD UI
make port-forward-argocd
# Open https://localhost:8080, user: admin, password:
make argocd-password

# 3. Access Grafana
make port-forward-grafana
# Open http://localhost:3000, user: admin, password: admin
```

### Cloud Deployment (Hetzner)

```bash
# Set your Hetzner API token
export TF_VAR_hcloud_token="your-token-here"

# Provision VPS with k3s
make hetzner-up

# Get kubeconfig
make hetzner-kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig_hetzner

# Apply ArgoCD bootstrap (GitOps takes over from here)
kubectl apply -f argocd/bootstrap.yaml

# Cleanup (saves money!)
make hetzner-destroy
```

## 🔑 Key Patterns Demonstrated

### 1. App-of-Apps Pattern
Single `bootstrap.yaml` deploys all applications. Add new apps by creating a file in `argocd/applications/`.

### 2. Sync Waves
Observability deploys first (`sync-wave: -1`) so monitoring is ready before apps start.

### 3. Helm-in-Kustomize
Complex charts (Prometheus, Loki) managed via `helmCharts` in Kustomization, allowing value overrides without Helm CLI.

### 4. GitOps-Only Deployments
No `kubectl apply` in CI/CD pipelines. Push to Git → ArgoCD syncs automatically.

### 5. Cost-Optimized Cloud
Hetzner VPS with auto-shutdown cron job prevents forgotten resources from burning money.

## 📊 Observability Stack

| Component | Purpose | Access |
|-----------|---------|--------|
| **Prometheus** | Metrics collection & alerting | Via Grafana |
| **Grafana** | Dashboards & visualization | `localhost:3000` |
| **Loki** | Log aggregation | Via Grafana |
| **Promtail** | Log shipping from pods | DaemonSet |

## 🛠️ Make Commands

```bash
make local-up          # Create k3d cluster + install ArgoCD + bootstrap
make local-down        # Destroy local cluster

make hetzner-up        # Provision Hetzner VPS with k3s
make hetzner-kubeconfig # Fetch kubeconfig from remote
make hetzner-destroy   # Tear down cloud infrastructure

make argocd-password   # Get ArgoCD admin password
make port-forward-argocd   # Forward ArgoCD UI to localhost:8080
make port-forward-grafana  # Forward Grafana to localhost:3000
```

## � Environment Variables Reference

All secrets/env vars used in this project. **Demo values are hardcoded—override for production.**

| Variable | Location | Demo Value | Production Override |
|----------|----------|------------|---------------------|
| `PAYLOAD_SECRET` | `apps/payload-cms/kustomization.yaml` | `super-secret-key-for-demo-only` | SealedSecret or External Secret |
| `DATABASE_URI` | `apps/payload-cms/kustomization.yaml` | `postgres://postgres:password@postgres:5432/payload` | Managed DB connection string |
| `POSTGRES_USER` | `apps/payload-cms/postgres.yaml` | `postgres` | Create dedicated app user |
| `POSTGRES_PASSWORD` | `apps/payload-cms/postgres.yaml` | `password` ⚠️ | Strong password via secret |
| `POSTGRES_DB` | `apps/payload-cms/postgres.yaml` | `payload` | Keep or customize |
| `TF_VAR_hcloud_token` | Shell environment | (you provide) | CI/CD secret or Vault |
| `KUBECONFIG` | Shell environment | `./kubeconfig_hetzner` | Service account or IAM |

### PayloadCMS-Specific (from your blog)

| Variable | Purpose | Notes |
|----------|---------|-------|
| `NEXT_PUBLIC_SERVER_URL` | Public URL for Next.js | e.g., `https://myblog.com` |
| `PAYLOAD_PUBLIC_SERVER_URL` | Payload admin URL | Same as above |
| `RESEND_API_KEY` | Email provider | For contact forms |
| `BLOB_READ_WRITE_TOKEN` | Vercel Blob storage | Media uploads |

## 🔒 Security Best Practices

### Demo vs Production Checklist

| Aspect | Demo (Current) | Production Required |
|--------|----------------|---------------------|
| **Secrets** | `secretGenerator` (plaintext in Git) | SealedSecrets or External Secrets Operator |
| **Passwords** | Hardcoded `password` | Generated, rotated, 20+ chars |
| **RBAC** | ArgoCD cluster-admin | Scoped `AppProject` with namespace restrictions |
| **Network** | No NetworkPolicies | Deny-all default + explicit allow rules |
| **TLS** | None (HTTP) | cert-manager + Let's Encrypt |
| **Images** | `:latest` tags | Immutable SHA digests |
| **Pod Security** | None | Pod Security Standards (restricted) |

### Recommended Secret Management

**Option 1: SealedSecrets (Simplest)**
```bash
# Install controller
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Encrypt secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to Git (safe!)
```

**Option 2: External Secrets Operator (Cloud-native)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payload-secrets
spec:
  secretStoreRef:
    name: vault-backend  # or aws-secrets-manager
  target:
    name: payload-secrets
  data:
    - secretKey: DATABASE_URI
      remoteRef:
        key: payload/database-uri
```

### RBAC Lockdown Example

```yaml
# Restrict ArgoCD to only payload namespace
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: payload-project
spec:
  destinations:
    - namespace: payload
      server: https://kubernetes.default.svc
  sourceRepos:
    - https://github.com/Tonikprofik/gitops-k8s-payloadcms
  clusterResourceWhitelist: []  # No cluster-wide resources
```

## 📚 Further Reading

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Helm Charts](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)
- [k3s/k3d Documentation](https://k3d.io/)
- [PayloadCMS Documentation](https://payloadcms.com/docs)

## � What I Learned Building This

A few things that tripped me up (so future me doesn't forget):

- **Sync waves matter** — PayloadCMS kept crashing on first deploy because Postgres wasn't ready. Adding `sync-wave: -1` to observability and `sync-wave: 1` to the app fixed the race condition.

- **Helm-in-Kustomize is fiddly** — Spent hours wondering why `helmCharts` wasn't working. Turns out ArgoCD needs the repo-server configured with `--enable-helm`. The Kustomize docs don't mention this.

- **Hetzner > AWS for learning** — Started with AWS EKS but ~€70/month for a learning cluster felt wasteful. Hetzner's €4/month VPS runs k3s perfectly fine.

- **GitOps changes how you think** — After a week of "push to Git, ArgoCD syncs", running `kubectl apply` manually feels wrong. That's the point.

## 👤 Author

**GitHub**: [@Tonikprofik](https://github.com/Tonikprofik)

---

* learning project on SRE/Platform Engineering skills: GitOps, Kubernetes, IaC, and Observability.*
