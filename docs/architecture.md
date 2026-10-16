# Architecture Overview
## TS Academy DevOps Capstone Project

---

**Document Version:** 1.0
**Last Updated:** 2026-10-16
**Owner:** DevOps / SRE Team
**Classification:** Internal

---

## Table of Contents

1. [Capstone 1 Architecture — Voting App on EKS](#1-capstone-1-architecture--voting-app-on-eks)
2. [Capstone 2 Architecture — Robot Shop Observability](#2-capstone-2-architecture--robot-shop-observability)
3. [Infrastructure Overview](#3-infrastructure-overview)

---

## 1. Capstone 1 Architecture — Voting App on EKS

### 1.1 Overview

Capstone 1 deploys a **multi-service Voting Application** on Amazon EKS using a fully automated CI/CD pipeline powered by GitHub Actions and packaged with Helm. The application allows users to vote between two options and displays results in real-time.

### 1.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER WORKFLOW                                  │
│                                                                             │
│  Developer  ──git push──►  GitHub (main branch)                            │
│                               │                                             │
│                               ▼                                             │
│                    ┌─────────────────────┐                                 │
│                    │   GitHub Actions     │                                 │
│                    │   CI/CD Pipeline     │                                 │
│                    │                      │                                 │
│                    │  1. Run Unit Tests   │                                 │
│                    │  2. Trivy Image Scan │                                 │
│                    │  3. Build Images     │                                 │
│                    │  4. Push to Docker   │                                 │
│                    │     Hub              │                                 │
│                    │  5. Helm Deploy      │                                 │
│                    │     to EKS           │                                 │
│                    └──────────┬──────────┘                                 │
│                               │                                             │
└───────────────────────────────┼─────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DOCKER HUB (Image Registry)                              │
│                                                                             │
│   vote:latest   result:latest   worker:latest                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                                │  Helm pull images
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AMAZON EKS CLUSTER (eu-west-1)                           │
│                    Namespace: voting-app                                    │
│                                                                             │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                 │
│   │  vote        │    │  result      │    │  worker      │                 │
│   │  (Python)    │    │  (Node.js)   │    │  (Go)        │                 │
│   │  Port 80     │    │  Port 80     │    │  (internal)  │                 │
│   │  2 replicas  │    │  2 replicas  │    │  1 replica   │                 │
│   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                 │
│          │                   │                   │                         │
│          │  votes            │  reads            │ reads/writes            │
│          ▼                   │                   ▼                         │
│   ┌──────────────┐           │          ┌──────────────┐                   │
│   │  Redis       │           │          │  PostgreSQL  │                   │
│   │  (in-memory) │◄──────────┘          │  (persistent)│                  │
│   │  Port 6379   │    reads results      │  Port 5432  │                   │
│   │  1 replica   │                      │  1 replica  │                   │
│   └──────────────┘                      └──────────────┘                  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │                    AWS Load Balancer                             │      │
│   │       vote-svc (LoadBalancer)  │  result-svc (LoadBalancer)     │      │
│   └─────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Component Descriptions

| Component | Technology | Purpose | Replicas | Port |
|-----------|------------|---------|----------|------|
| **vote** | Python (Flask) | Frontend for casting votes | 2 | 80 |
| **result** | Node.js (Express) | Frontend showing vote results in real-time | 2 | 80 |
| **worker** | Go | Background worker consuming votes from Redis, writing to PostgreSQL | 1 | Internal |
| **Redis** | Redis 7 | In-memory vote queue (fast writes from vote service) | 1 | 6379 |
| **PostgreSQL** | PostgreSQL 15 | Persistent storage for aggregated vote counts | 1 | 5432 |
| **GitHub Actions** | YAML Workflows | CI/CD automation: test → scan → build → deploy | — | — |
| **Helm** | Helm 3 | Package manager for Kubernetes manifests | — | — |

### 1.4 CI/CD Pipeline Detail

```
GitHub Push (main)
    │
    ├── Job: test
    │       └── Run unit tests for vote, result, worker services
    │
    ├── Job: security-scan
    │       └── Trivy vulnerability scan on each service image
    │           └── Fail build if CRITICAL CVEs found
    │
    ├── Job: build-push (on: test success)
    │       ├── docker build -t <user>/vote:$SHA .
    │       ├── docker build -t <user>/result:$SHA .
    │       ├── docker build -t <user>/worker:$SHA .
    │       └── docker push to Docker Hub
    │
    └── Job: deploy (on: build success)
            └── helm upgrade --install voting-app ./helm/voting-app \
                    --set vote.image.tag=$SHA \
                    --set result.image.tag=$SHA \
                    --set worker.image.tag=$SHA \
                    --namespace voting-app \
                    --create-namespace
```

### 1.5 Network Flow

```
User Browser
    │
    ├── HTTP → AWS Load Balancer → vote service (port 80)
    │                                  │
    │                                  └── POST /vote → Redis LPUSH "votes" payload
    │
    └── HTTP → AWS Load Balancer → result service (port 80)
                                       │
                                       └── GET /result → PostgreSQL SELECT * FROM votes

Background:
    worker pod
        └── Redis BRPOP "votes" → parse payload → PostgreSQL INSERT/UPDATE vote count
```

### 1.6 Security Controls

| Control | Implementation |
|---------|---------------|
| **Non-root containers** | All Dockerfiles set `USER nonroot` (uid 65534) |
| **No secrets in Git** | Docker credentials stored as GitHub Actions Secrets |
| **Image scanning** | Trivy scans all images in CI; CRITICAL severity fails the build |
| **RBAC** | Kubernetes ServiceAccount with minimal permissions per namespace |
| **Resource limits** | All deployments define CPU/memory `requests` and `limits` |
| **Read-only filesystem** | Worker runs with `readOnlyRootFilesystem: true` |
| **Network policies** | `vote` can only reach `redis`; `result` can only reach `postgres` |

---

## 2. Capstone 2 Architecture — Robot Shop Observability

### 2.1 Overview

Capstone 2 implements a full **observability stack** for the Robot Shop microservices application on Amazon EKS, covering all three pillars of observability: **Metrics**, **Logging**, and **Distributed Tracing**. The stack uses the Prometheus/Grafana ecosystem for metrics and alerting, Fluent Bit + Loki for log aggregation, and OpenTelemetry + Jaeger for distributed tracing.

### 2.2 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              ROBOT SHOP MICROSERVICES (Namespace: robot-shop)               │
│                                                                             │
│   web   catalogue   cart   payment   user   shipping   ratings   mysql      │
│   redis   mongodb   rabbitmq                                                │
│                                                                             │
│   Each pod exposes /metrics endpoint (Prometheus format)                   │
│   Each pod writes structured JSON logs to stdout                            │
│   payment service instrumented with OpenTelemetry SDK                      │
└───────────────────┬────────────────────┬─────────────────────┬─────────────┘
                    │                    │                      │
              METRICS path          LOGS path           TRACES path
                    │                    │                      │
                    ▼                    ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              OBSERVABILITY STACK (Namespace: monitoring / logging)          │
│                                                                             │
│  ┌──────────────┐   ┌─────────────────────────────────┐  ┌──────────────┐  │
│  │  Prometheus  │   │       Fluent Bit (DaemonSet)    │  │ OTel Collector│  │
│  │  (scrapes    │   │   Reads container logs from     │  │  (receives   │  │
│  │   /metrics   │   │   /var/log/containers/*.log     │  │   spans from │  │
│  │   every 30s) │   │   Parses JSON, adds k8s labels  │  │   payment)   │  │
│  └──────┬───────┘   └────────────────┬────────────────┘  └──────┬───────┘  │
│         │                            │                           │           │
│         ▼                            ▼                           ▼           │
│  ┌──────────────┐   ┌────────────────────────────────┐  ┌──────────────┐   │
│  │ AlertManager │   │         Loki                   │  │   Jaeger     │   │
│  │  (routes     │   │  (log aggregation & indexing)  │  │  (trace      │   │
│  │   alerts to  │   │   Stores logs with k8s labels  │  │   storage &  │   │
│  │   Slack /    │   │   as index, raw log as chunk   │  │   UI)        │   │
│  │   PagerDuty) │   └──────────────┬─────────────────┘  └──────┬───────┘  │
│  └──────────────┘                  │                             │           │
│                                    │                             │           │
│         ┌──────────────────────────┼─────────────────────────────┘           │
│         ▼                          ▼                                          │
│  ┌──────────────────────────────────────────────────────┐                   │
│  │                        GRAFANA                        │                  │
│  │  ┌────────────────┐  ┌──────────────┐  ┌──────────┐  │                  │
│  │  │ Robot Shop     │  │ Log Explorer │  │ Trace    │  │                  │
│  │  │ SLO Dashboard  │  │ (Loki source)│  │ Viewer   │  │                  │
│  │  │ (Prometheus)   │  │              │  │ (Jaeger) │  │                  │
│  │  └────────────────┘  └──────────────┘  └──────────┘  │                  │
│  └──────────────────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
                    │
                    ▼ Alert fired
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ALERTING DESTINATIONS                                │
│                                                                             │
│   Slack #sre-incidents (Critical)    Slack #sre-alerts (Warning)           │
│   PagerDuty (P1/P2 incidents)        Email (SLA breach notifications)      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Observability Pillars

| Pillar | Tool | Data Collected | Storage | Retention |
|--------|------|----------------|---------|-----------|
| **Metrics** | Prometheus + kube-prometheus-stack | HTTP request rates, latency histograms, error rates, pod CPU/memory, SLO burn rates | Prometheus TSDB (local) | 15 days |
| **Logging** | Fluent Bit → Loki | Structured JSON application logs, Kubernetes system logs, nginx access logs | Loki + S3 (long-term) | 30 days hot, 1 year S3 |
| **Tracing** | OTel SDK → OTel Collector → Jaeger | Distributed request traces, span timing, error flags (payment service) | Jaeger (Cassandra/ElasticSearch) | 7 days |

### 2.4 Alert Flow

```
Prometheus evaluates PrometheusRule every 30s
    │
    ├── Rule matches (e.g. error rate > 1% for 5m)
    │
    ▼
AlertManager receives alert
    │
    ├── Group by: [alertname, service, severity]
    ├── Wait: 30s (group_wait) before first notification
    ├── Repeat: Every 4h (repeat_interval) if still firing
    │
    ├── severity=critical → Slack #sre-incidents + PagerDuty
    └── severity=warning  → Slack #sre-alerts
```

### 2.5 SLO Monitoring Architecture

```
Prometheus (scrapes /metrics)
    │
    ├── Records: error rate, latency P99, availability per service
    │
    ▼
PrometheusRule (slo-alerts.yaml)
    │
    ├── RobotShopWebErrorBudgetCritical  (1h window, 14× burn rate)
    ├── RobotShopWebErrorBudgetWarning   (6h window, 6× burn rate)
    ├── RobotShopWebAvailabilityBreach   (30m window, availability < 99.5%)
    └── (same pattern for catalogue, cart, payment)
    │
    ▼
Grafana SLO Dashboard (grafana-dashboard.json)
    │
    ├── Panel: Error Budget Remaining (gauge)
    ├── Panel: Burn Rate 1h / 6h (time series)
    ├── Panel: Availability % (stat)
    ├── Panel: P99 Latency by Service (time series)
    └── Panel: HTTP Error Rate by Service (time series)
```

### 2.6 Data Retention Policy

| Data Type | Hot Retention | Cold Retention | Storage |
|-----------|--------------|----------------|---------|
| Prometheus metrics | 15 days | N/A | EBS (gp3) |
| Loki logs (recent) | 30 days | N/A | EBS (gp3) |
| Loki logs (archive) | N/A | 1 year | S3 Standard-IA |
| Jaeger traces | 7 days | N/A | Cassandra (EBS) |
| Grafana dashboards | Persistent | N/A | EBS (gp3) |
| Alert history | 30 days | N/A | Alertmanager |

---

## 3. Infrastructure Overview

### 3.1 AWS EKS Cluster Specification

| Parameter | Value |
|-----------|-------|
| **Cloud Provider** | AWS |
| **Region** | eu-west-1 (Ireland) |
| **Kubernetes Version** | 1.29 |
| **Cluster Name** | `ts-academy-prod` |
| **Control Plane** | AWS Managed (EKS) |
| **Node Group Type** | Managed Node Groups |
| **Worker Node Type** | `t3.medium` (2 vCPU, 4 GiB RAM) |
| **Node Count** | 3 (min) → 6 (max) via Cluster Autoscaler |
| **Availability Zones** | eu-west-1a, eu-west-1b, eu-west-1c |
| **Networking** | AWS VPC CNI (native pod IPs) |
| **Storage Class** | AWS EBS gp3 (default) |
| **Ingress Controller** | NGINX Ingress Controller |
| **Load Balancer** | AWS Network Load Balancer (NLB) |
| **Certificate Management** | cert-manager + Let's Encrypt |
| **Provisioning** | Terraform (see `capstone-1/terraform/`) |

### 3.2 Namespace Layout

| Namespace | Purpose | Key Workloads |
|-----------|---------|---------------|
| `voting-app` | Capstone 1 — Voting application | vote, result, worker, redis, postgres |
| `robot-shop` | Capstone 2 — Robot Shop microservices | web, catalogue, cart, payment, user, shipping, ratings, mysql, mongodb, redis, rabbitmq |
| `monitoring` | Observability stack — metrics & alerts | Prometheus, Alertmanager, Grafana, OTel Collector, Jaeger |
| `logging` | Observability stack — logs | Fluent Bit (DaemonSet), Loki |
| `ingress-nginx` | Ingress controller | nginx-ingress-controller |
| `cert-manager` | TLS certificate management | cert-manager, cainjector, webhook |
| `kube-system` | Kubernetes system components | CoreDNS, aws-node, kube-proxy, cluster-autoscaler |

### 3.3 Resource Summary

| Namespace | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage (PVC) |
|-----------|-------------|-----------|----------------|--------------|---------------|
| `voting-app` | 550m | 1100m | 704Mi | 1408Mi | 1 × 8Gi (postgres) |
| `robot-shop` | 1800m | 3600m | 2304Mi | 4608Mi | 1 × 20Gi (mysql), 1 × 10Gi (mongodb) |
| `monitoring` | 1000m | 2000m | 2048Mi | 4096Mi | 1 × 50Gi (prometheus), 1 × 20Gi (grafana) |
| `logging` | 400m | 800m | 512Mi | 1024Mi | 1 × 30Gi (loki) |
| **Total (approx)** | **~3.75 CPU** | **~7.5 CPU** | **~5.5 GiB** | **~11 GiB** | **~139 GiB EBS** |

### 3.4 Terraform Infrastructure

The EKS cluster is provisioned and managed via Terraform in `capstone-1/terraform/`:

```
capstone-1/terraform/
├── main.tf        # EKS cluster, VPC, node groups, IAM roles
├── variables.tf   # Input variables (region, cluster name, node type)
├── outputs.tf     # Cluster endpoint, kubeconfig, OIDC provider ARN
└── versions.tf    # Provider version constraints
```

**Key Terraform resources:**
- `aws_vpc` — Dedicated VPC with public + private subnets
- `aws_eks_cluster` — EKS control plane
- `aws_eks_node_group` — Managed worker node group
- `aws_iam_role` — EKS cluster role, node role, OIDC-federated service account roles
- `aws_ebs_csi_driver` — EBS CSI driver for persistent volume support

### 3.5 Helm Chart Structure (Capstone 1)

```
capstone-1/helm/voting-app/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default values
└── templates/
    ├── vote-deployment.yaml            # Vote service Deployment
    ├── vote-service.yaml               # Vote service Service (LoadBalancer)
    ├── result-deployment.yaml          # Result service Deployment
    ├── result-service.yaml             # Result service Service (LoadBalancer)
    ├── worker-deployment.yaml          # Worker Deployment
    ├── redis-deployment.yaml           # Redis Deployment + Service
    ├── postgres-deployment.yaml        # PostgreSQL Deployment + Service
    └── _helpers.tpl                    # Template helpers
```

---

*For questions about this architecture, contact the DevOps team at `#devops` on Slack.*
