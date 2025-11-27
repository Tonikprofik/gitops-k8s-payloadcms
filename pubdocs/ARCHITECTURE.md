# Architecture Deep Dive

## App-of-Apps Pattern Explained

ArgoCD's **App-of-Apps** pattern is a hierarchical approach where one "parent" Application manages multiple "child" Applications.

```
                    ┌─────────────────────────┐
                    │    bootstrap.yaml       │
                    │    (Parent App)         │
                    │                         │
                    │ Watches: argocd/        │
                    │          applications/  │
                    └───────────┬─────────────┘
                                │
           ┌────────────────────┼────────────────────┐
           │                    │                    │
           ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ observability   │  │ payload-cms     │  │ (future apps)   │
│ sync-wave: -1   │  │ sync-wave: 1    │  │ sync-wave: N    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Why This Pattern?

| Benefit | Explanation |
|---------|-------------|
| **Single Entrypoint** | One `kubectl apply` bootstraps entire cluster |
| **Self-Healing** | ArgoCD auto-corrects drift from Git state |
| **Declarative** | Git is the single source of truth |
| **Scalable** | Add apps by adding YAML files, no code changes |
| **Auditable** | Git history = deployment history |

## Sync Waves: Deployment Ordering

Sync waves control the order in which ArgoCD deploys resources.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploy first (negative = earlier)
```

### Our Sync Wave Strategy

| Wave | Application | Reason |
|------|-------------|--------|
| -1 | Observability | Monitoring must be ready before apps start |
| 0 | (default) | Standard applications |
| 1 | PayloadCMS | Depends on monitoring being available |

## Kustomize + Helm Integration

We use Kustomize's `helmCharts` field to deploy Helm charts without the Helm CLI.

```yaml
# apps/observability/kustomization.yaml
helmCharts:
  - name: kube-prometheus-stack
    repo: https://prometheus-community.github.io/helm-charts
    version: 56.0.0
    releaseName: prometheus
    valuesFile: values-prometheus.yaml  # Override default values
```

### Why Not Pure Helm?

| Approach | Pros | Cons |
|----------|------|------|
| **Pure Helm** | Native chart ecosystem | Requires Helm CLI, tiller history |
| **Pure Kustomize** | Simple, patches | Can't use charts |
| **Kustomize + Helm** ✅ | Best of both | Slightly more complex |

## PayloadCMS Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    payload namespace                         │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Ingress                            │   │
│  │              payload.localhost:8080                   │   │
│  │                        │                              │   │
│  │                        ▼                              │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │              Service (ClusterIP)               │  │   │
│  │  │                port: 80 → 3000                 │  │   │
│  │  └───────────────────────┬────────────────────────┘  │   │
│  │                          │                            │   │
│  │                          ▼                            │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │             Deployment (1 replica)             │  │   │
│  │  │                                                │  │   │
│  │  │  ┌────────────────────────────────────────┐   │  │   │
│  │  │  │         PayloadCMS Container           │   │  │   │
│  │  │  │  - TypeScript/React/Next.js            │   │  │   │
│  │  │  │  - Port: 3000                          │   │  │   │
│  │  │  │  - Liveness probe: /api/health         │   │  │   │
│  │  │  │  - Resources: 250m-500m CPU            │   │  │   │
│  │  │  │              512Mi-1Gi memory          │   │  │   │
│  │  │  └────────────────────────────────────────┘   │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                          │                            │   │
│  │                          │ DATABASE_URI               │   │
│  │                          ▼                            │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │           StatefulSet (PostgreSQL)             │  │   │
│  │  │                                                │  │   │
│  │  │  - postgres:16-alpine                         │  │   │
│  │  │  - Port: 5432                                 │  │   │
│  │  │  - Headless Service (ClusterIP: None)         │  │   │
│  │  │  - PersistentVolumeClaim: 1Gi                 │  │   │
│  │  │                                                │  │   │
│  │  │  Why StatefulSet instead of Deployment?        │  │   │
│  │  │  → Stable network identity (postgres-0)        │  │   │
│  │  │  → Ordered pod creation/deletion               │  │   │
│  │  │  → Stable persistent storage                   │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Infrastructure Layer (Hetzner)

```
┌─────────────────────────────────────────────────────────────┐
│                     Terraform                                │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Hetzner Cloud                        │  │
│  │                                                        │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │             VPS (cpx11)                         │  │  │
│  │  │  - 2 vCPU, 2GB RAM                              │  │  │
│  │  │  - Ubuntu 22.04                                 │  │  │
│  │  │  - Location: Nuremberg (EU)                     │  │  │
│  │  │                                                 │  │  │
│  │  │  cloud-init (user_data.yml):                    │  │  │
│  │  │  1. Install k3s                                 │  │  │
│  │  │  2. Install ArgoCD                              │  │  │
│  │  │  3. Set auto-shutdown cron (cost savings)       │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Why Hetzner?

| Factor | Hetzner | AWS/GCP |
|--------|---------|---------|
| **Cost** | ~€4/month for cpx11 | ~$30-50/month for equivalent |
| **Simplicity** | Single VPS, no networking complexity | VPC, subnets, NAT gateways |
| **EU Data** | GDPR-friendly, EU datacenters | Available but more config |
| **Learning** | Great for demos | Overkill for learning |

## Observability Stack

```
┌─────────────────────────────────────────────────────────────┐
│                  monitoring namespace                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Grafana                            │    │
│  │  - Unified dashboards                               │    │
│  │  - Data sources: Prometheus, Loki                   │    │
│  │  - Access: localhost:3000                           │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                    │
│         ┌───────────────┴───────────────┐                   │
│         │                               │                    │
│         ▼                               ▼                    │
│  ┌──────────────────┐          ┌──────────────────┐         │
│  │    Prometheus    │          │      Loki        │         │
│  │                  │          │                  │         │
│  │  - Metrics       │          │  - Logs          │         │
│  │  - Alerting      │          │  - LogQL queries │         │
│  │  - ServiceMonitor│          │                  │         │
│  └──────────────────┘          └────────┬─────────┘         │
│         ▲                               ▲                    │
│         │ scrape                        │ push               │
│         │                               │                    │
│  ┌──────┴───────────────────────────────┴──────┐            │
│  │              All Kubernetes Pods             │            │
│  │              (via Promtail DaemonSet)        │            │
│  └──────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Network Flow

```
                           Internet
                              │
                              ▼
                    ┌─────────────────┐
                    │  Traefik Ingress │  (k3s default)
                    │  Controller      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   payload.localhost   grafana.localhost   argocd.localhost
        │                    │                    │
        ▼                    ▼                    ▼
   payload-cms svc     grafana svc         argocd-server svc
        │                    │                    │
        ▼                    ▼                    ▼
   PayloadCMS pod      Grafana pod         ArgoCD pod
```

## Security Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   argocd    │  │  monitoring │  │      payload        │  │
│  │  namespace  │  │  namespace  │  │     namespace       │  │
│  │             │  │             │  │                     │  │
│  │ ArgoCD RBAC │  │ Prometheus  │  │ App secrets         │  │
│  │ (separate   │  │ scrape RBAC │  │ (secretGenerator)   │  │
│  │  service    │  │             │  │                     │  │
│  │  account)   │  │             │  │ ⚠️ Demo only!       │  │
│  └─────────────┘  └─────────────┘  │ Use SealedSecrets   │  │
│                                     │ in production       │  │
│                                     └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Failure Scenarios & Recovery

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| Pod crash | Liveness probe fails | Kubernetes restarts pod |
| Config drift | ArgoCD "OutOfSync" | ArgoCD self-heals (prune + sync) |
| Node failure | Prometheus alerts | k3s reschedules pods |
| Git repo unavailable | ArgoCD sync fails | Cluster continues with last known state |
| Database corruption | Application errors | Restore from PVC snapshot |

## Scaling Considerations

For production, consider:

1. **Database**: Managed PostgreSQL (RDS, Cloud SQL) instead of StatefulSet
2. **Secrets**: External Secrets Operator with Vault or AWS Secrets Manager
3. **HA ArgoCD**: Multiple replicas with Redis for session state
4. **Multi-cluster**: ArgoCD can manage multiple clusters from one control plane
5. **Network Policies**: Restrict pod-to-pod communication
6. **HPA**: Horizontal Pod Autoscaler for PayloadCMS based on CPU/memory

---

## Multi-Cloud Deployment Matrix

| Aspect | k3d (Local) | Hetzner Shared | Hetzner Dedicated | AWS EKS | Talos (Planned) |
|--------|-------------|----------------|-------------------|---------|-----------------|
| **Cluster Type** | k3s in Docker | Single-node k3s | k3s or Talos | Managed EKS | Immutable OS |
| **Node Count** | 2 agents | 1 node | 1-3 nodes | Fargate/EC2 | 1+ control plane |
| **Cost/month** | $0 | €3.49-5.49 | ~€45 (AX41) | $73-150+ | Hardware only |
| **Ingress** | Traefik (k3d) | Traefik (k3s) | Traefik/Nginx | AWS ALB | Traefik/Cilium |
| **Storage** | local-path | local-path | local-path/Longhorn | EBS CSI | local-path |
| **Bootstrap** | `make local-up` | Terraform + cloud-init | Terraform + Talos | Terraform modules | `talosctl apply` |
| **SSH Access** | N/A (Docker) | Yes | Yes (or Talos: None) | Via SSM | ❌ API-only |
| **Best For** | Development | Demos, learning | Serious workloads | Enterprise | Security-focused |

### Cost Comparison (Monthly, excl. VAT)

```
Local k3d:           $0 (your laptop)

# SHARED VPS (Cost-Optimized) - NEW lower tier!
Hetzner CX11:        €3.49 - 2 vCPU, 4GB RAM, 40GB NVMe ⭐ CHEAPEST
Hetzner CAX11 (ARM): €3.79 - 2 vCPU, 4GB RAM, 40GB NVMe (Ampere)

# SHARED VPS (Regular) - currently used
Hetzner CX22/CPX11:  €4.99 - 2 vCPU, 4GB RAM, 40GB NVMe
Hetzner CX32/CPX21:  €5.49 - 4 vCPU, 8GB RAM, 80GB NVMe

# DEDICATED (bare-metal)
Hetzner AX41-NVMe:   €45 - Ryzen 3600, 64GB RAM, 2x512GB NVMe

# MANAGED K8S
AWS EKS:             $73+ (cluster fee) + EC2/Fargate compute
GKE Autopilot:       $74+ (cluster management fee)
```

### Cheapest Production-Viable Options

| Option | Cost | RAM | Can Run k3s + PayloadCMS? |
|--------|------|-----|---------------------------|
| **CX11 (IPv6-only)** | €2.99 | 4GB | ✅ Yes (save €0.50 skipping IPv4) |
| **CX11 (with IPv4)** | €3.49 | 4GB | ✅ Yes |
| **CAX11 (ARM)** | €3.79 | 4GB | ✅ Yes (if ARM image available) |
| **Hourly billing** | €0.0056/hr | - | ✅ ~€4/month if always on |

> **Tip**: Use hourly billing + auto-shutdown cron for learning. Destroy when not using.

---

## PostgreSQL Production Patterns

### Current Demo Setup (Not for Production)

```yaml
# What we have now:
- postgres:16-alpine StatefulSet (single replica)
- 1Gi PVC (no backup)
- Hardcoded password in manifest ⚠️
- No resource limits
- No connection pooling
- No monitoring (ServiceMonitor)
```

### Production Options

**Option 1: CloudNativePG Operator (Recommended for K8s-native)**

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: payload-db
spec:
  instances: 3  # HA with streaming replication
  storage:
    size: 10Gi
    storageClass: longhorn
  backup:
    barmanObjectStore:
      destinationPath: s3://backups/payload
      s3Credentials:
        accessKeyId:
          name: s3-creds
          key: ACCESS_KEY
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m
```

**Option 2: Managed PostgreSQL (Simplest)**

| Provider | Service | Cost | Notes |
|----------|---------|------|-------|
| **Neon** | Serverless Postgres | Free tier, then $19/mo | PayloadCMS has `@payloadcms/db-vercel-postgres` |
| **Supabase** | Managed Postgres | Free tier, then $25/mo | Includes auth, storage |
| **Hetzner** | (none) | N/A | Must self-host |
| **AWS RDS** | RDS PostgreSQL | $15+/mo | Multi-AZ available |

**Option 3: Backup CronJob (Quick Win)**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:16-alpine
              command:
                - /bin/sh
                - -c
                - |
                  pg_dump -h postgres -U postgres payload | \
                  gzip > /backup/payload-$(date +%Y%m%d).sql.gz
              volumeMounts:
                - name: backup
                  mountPath: /backup
          volumes:
            - name: backup
              persistentVolumeClaim:
                claimName: backup-pvc
```

### PayloadCMS Database Configuration

Your `package.json` shows `@payloadcms/db-vercel-postgres` - this supports:
- Connection pooling via Vercel's edge adapter
- Works with Neon, Supabase, or any PostgreSQL

For self-hosted K8s, switch to standard `@payloadcms/db-postgres`:
```ts
// payload.config.ts
import { postgresAdapter } from '@payloadcms/db-postgres'

export default buildConfig({
  db: postgresAdapter({
    pool: {
      connectionString: process.env.DATABASE_URI,
      max: 10,  // Connection pool size
    },
  }),
})
```

---

## Talos Linux Roadmap

### Why Talos?

| Feature | Traditional Linux (Ubuntu/Debian) | Talos Linux |
|---------|----------------------------------|-------------|
| **SSH** | Yes (attack surface) | ❌ No SSH, API-only |
| **Package Manager** | apt/yum | ❌ Immutable, no packages |
| **OS Updates** | Manual/unattended-upgrades | Atomic A/B upgrades |
| **Configuration** | Scattered files | Single YAML machine config |
| **Attack Surface** | Large (systemd, cron, users) | Minimal (just Kubernetes) |
| **Drift** | Possible | Impossible (immutable) |

### Planned Directory Structure

```
infra/
├── hetzner/              # Existing VPS setup (k3s)
├── aws/                  # Existing EKS stubs
└── talos/                # NEW: Talos infrastructure
    ├── README.md         # Talos-specific documentation
    │
    ├── bare-metal/       # For homelab / physical servers
    │   ├── controlplane.yaml   # Machine config (control plane)
    │   ├── worker.yaml         # Machine config (worker nodes)
    │   └── talosconfig         # Client config (generated)
    │
    └── hetzner-dedicated/      # For Hetzner dedicated servers
        ├── main.tf             # Terraform for dedicated server
        ├── talos-config.yaml   # Machine config template
        └── variables.tf
```

### Hetzner Dedicated Options for Talos

| Server | Specs | Cost | Talos Suitable |
|--------|-------|------|----------------|
| **AX41-NVMe** | Ryzen 3600, 64GB, 2x512GB NVMe | €45/mo | ✅ Best value |
| **AX52** | Ryzen 5600X, 64GB, 2x1TB NVMe | €67/mo | ✅ More storage |
| **AX102** | Ryzen 9 5950X, 128GB, 2x1.92TB NVMe | €139/mo | ✅ High performance |

### Talos Bootstrap Workflow

```bash
# 1. Generate configs (one-time)
talosctl gen config gitops-cluster https://<control-plane-ip>:6443

# 2. Apply to node (no SSH needed!)
talosctl apply-config --insecure --nodes <ip> --file controlplane.yaml

# 3. Bootstrap cluster
talosctl bootstrap --nodes <ip>

# 4. Get kubeconfig
talosctl kubeconfig --nodes <ip>

# 5. Deploy ArgoCD (same as before)
kubectl apply -f argocd/bootstrap.yaml
```

### Talos + GitOps Integration

```yaml
# Machine config can include inline manifests for ArgoCD
machine:
  kubelet:
    extraArgs:
      rotate-server-certificates: true
cluster:
  inlineManifests:
    - name: argocd-namespace
      contents: |
        apiVersion: v1
        kind: Namespace
        metadata:
          name: argocd
```

---

## ArgoCD: Beyond Drift Detection

ArgoCD isn't just about detecting drift—it's a complete GitOps delivery platform.

### Core Capabilities

| Feature | What It Does | Industry Value |
|---------|--------------|----------------|
| **Drift Detection** | Compares live cluster state vs Git | Compliance auditing, prevents "works on my machine" |
| **Self-Healing** | Auto-reverts manual `kubectl` changes | Enforces GitOps discipline, prevents shadow IT |
| **Sync Waves** | Ordered deployments (infra → apps) | Dependency management without scripts |
| **Health Checks** | Custom resource health assessment | Know when deploy actually succeeded |
| **Rollback** | One-click revert to any Git commit | Fast incident recovery |
| **RBAC + SSO** | Fine-grained access control | Enterprise security requirements |
| **Multi-cluster** | Manage 100+ clusters from one ArgoCD | Platform team scaling |

### What ArgoCD Detects

```bash
# Any of these trigger "OutOfSync" status:
kubectl scale deployment/payload-cms --replicas=3  # Manual scaling
kubectl set image deployment/payload-cms ...        # Image change
kubectl delete pod payload-cms-xxx                  # Pod deletion (transient)
kubectl edit configmap ...                          # Config changes
```

### Trade-offs to Understand

| Pro | Con |
|-----|-----|
| Git = single source of truth | Must commit even small changes |
| Full audit trail | Learning curve for teams |
| Self-healing prevents drift | Can't do quick `kubectl` hotfixes |
| Declarative = reproducible | Imperative scripts need refactoring |
| Multi-cluster ready | Overkill for single tiny app |

---

## Possible Extensions

Ideas for extending this project (learning & portfolio value):

### 🔐 Security Enhancements
- [ ] **SealedSecrets** - Encrypt secrets in Git
- [ ] **Kyverno/OPA** - Policy-as-code (enforce labels, resource limits)
- [ ] **Falco** - Runtime threat detection
- [ ] **Trivy Operator** - Container image CVE scanning

### 📊 Observability Upgrades
- [ ] **Tempo** - Distributed tracing (Grafana stack)
- [ ] **Custom dashboards** - PayloadCMS-specific Grafana panels
- [ ] **Alertmanager rules** - PagerDuty/Slack integration
- [ ] **OpenTelemetry** - Instrument PayloadCMS with traces

### 🚀 CI/CD Integration
- [ ] **GitHub Actions** - Build PayloadCMS image on push
- [ ] **ArgoCD Image Updater** - Auto-update image tags from registry
- [ ] **Renovate Bot** - Auto-update Helm chart versions
- [ ] **Preview Environments** - ArgoCD ApplicationSets per PR

### ☸️ Kubernetes Patterns
- [ ] **HPA** - Horizontal Pod Autoscaler for PayloadCMS
- [ ] **PodDisruptionBudgets** - Graceful node drains
- [ ] **NetworkPolicies** - Micro-segmentation
- [ ] **Istio/Linkerd** - Service mesh (mTLS, traffic management)

### 🏗️ Infrastructure
- [ ] **Talos Linux** - Immutable Kubernetes OS (planned)
- [ ] **Longhorn** - Distributed storage for HA
- [ ] **cert-manager** - Automated TLS certificates
- [ ] **External-DNS** - Auto-manage DNS records

### 📚 Documentation
- [ ] **Architecture Decision Records (ADRs)** - Document "why" decisions
- [ ] **Runbooks** - Incident response procedures
- [ ] **Cost analysis** - Breakdown of monthly spend

---

## Learning Resources

| Topic | Resource | Why |
|-------|----------|-----|
| **GitOps** | [OpenGitOps Principles](https://opengitops.dev/) | Industry standard definition |
| **ArgoCD** | [ArgoCD Docs](https://argo-cd.readthedocs.io/) | Official reference |
| **k3s** | [k3s Docs](https://docs.k3s.io/) | Lightweight K8s |
| **Talos** | [Talos Docs](https://www.talos.dev/docs/) | Immutable K8s OS |
| **Prometheus** | [Prometheus Book](https://prometheus.io/docs/) | Metrics & alerting |
| **12 Factor Apps** | [12factor.net](https://12factor.net/) | Cloud-native app design |
