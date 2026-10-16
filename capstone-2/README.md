# Capstone 2: Observability Stack (Keep It Running)
## Robot Shop Production Observability & Reliability Engineering

---

## 1. Overview

This project implements a full production-grade observability platform for the Stan's Robot Shop microservices application running on Amazon EKS. It covers the **three pillars of observability**:

- **Metrics & Alerting**: Prometheus (via `kube-prometheus-stack`), Alertmanager (Slack routing), and custom Grafana SLO dashboards.
- **Log Aggregation**: Fluent Bit DaemonSet parsing container logs, enriching Kubernetes metadata, and forwarding to Grafana Loki.
- **Distributed Tracing**: OpenTelemetry Collector receiving OTLP spans from microservices (such as the Payment service) and exporting to Jaeger.
- **Site Reliability Engineering (SRE)**: SLOs & Error Budget Policy, multi-window burn rate alerts, comprehensive on-call runbooks, and a blameless postmortem template.

---

## 2. Architecture & Tech Stack

```
                        ROBOT SHOP MICROSERVICES (robot-shop namespace)
                         [web] [catalogue] [cart] [payment] [shipping] ...
                                    │                │             │
                ┌───────────────────┘                │             └───────────────────┐
                │ Metrics (/metrics)                 │ JSON Logs (stdout)              │ OTLP Spans
                ▼                                    ▼                                 ▼
   ┌──────────────────────────┐         ┌─────────────────────────┐       ┌────────────────────────┐
   │ kube-prometheus-stack    │         │ Fluent Bit (DaemonSet)  │       │ OTel Collector         │
   │ - Prometheus (15d ret)   │         │ - Enriches K8s labels   │       │ - Receives 4317/4318   │
   │ - Alertmanager (Slack)   │         │ - Filters noise         │       │ - Exports to Jaeger    │
   └────────────┬─────────────┘         └────────────┬────────────┘       └───────────┬────────────┘
                │                                    ▼                                │
                │                           ┌─────────────────┐                       ▼
                │                           │ Loki (7d ret)   │              ┌─────────────────┐
                │                           └────────┬────────┘              │ Jaeger Tracing  │
                ▼                                    ▼                       └────────┬────────┘
        ┌─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
   ┌─────────────────────────────────────────────────────────┐
   │ GRAFANA (Unified Dashboards, Logs Explorer, Traces UI) │
   └─────────────────────────────────────────────────────────┘
```

---

## 3. Prerequisites

- Kubernetes cluster (Amazon EKS v1.28+)
- Helm v3.12+
- `kubectl` configured with cluster admin context
- AWS EBS CSI driver installed and default StorageClass (`gp2` or `gp3`) configured

---

## 4. Step-by-Step Deployment Guide

### Step 1: Create Namespaces

```bash
kubectl create namespace robot-shop
kubectl create namespace monitoring
kubectl create namespace logging
```

### Step 2: Deploy Stan's Robot Shop Application

Add the Robot Shop Helm repository and deploy with custom storage classes:

```bash
helm repo add robot-shop https://instana.github.io/robot-shop
helm repo update

# Install without proprietary agents, using standard persistent storage
helm install robot-shop robot-shop/robot-shop \
  --namespace robot-shop \
  --set redis.storageClassName=gp2 \
  --set mongodb.storageClassName=gp2
```

Verify pods are running:

```bash
kubectl get pods -n robot-shop -w
```

### Step 3: Deploy `kube-prometheus-stack` (Metrics, Alerting, Grafana)

Add Prometheus community repository and install using the tailored values file:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-stack-values.yaml
```

Apply the SLO multi-window burn rate alert rules:

```bash
kubectl apply -f monitoring/slo-alerts.yaml
```

Configure Slack notifications:

```bash
# Update secret with your actual webhook URL first!
kubectl apply -f monitoring/alertmanager-config.yaml
```

### Step 4: Deploy Loki (Log Store)

Add Grafana Helm repository and install Loki:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki \
  --namespace logging \
  --values logging/loki-values.yaml
```

### Step 5: Deploy Fluent Bit (Log Forwarder)

Install Fluent Bit configured to stream container logs to Loki:

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values logging/fluent-bit-values.yaml
```

### Step 6: Deploy Jaeger & OpenTelemetry Collector (Distributed Tracing)

Install Jaeger in the monitoring namespace:

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

helm install jaeger jaegertracing/jaeger \
  --namespace monitoring \
  --set provisionDataStore.cassandra=false \
  --set allInOne.enabled=true
```

Deploy the OpenTelemetry Collector into the `robot-shop` namespace:

```bash
kubectl apply -f tracing/otel-collector-config.yaml
```

### Step 7: Import Grafana Dashboard

1. Port-forward to Grafana:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
   ```
2. Open `http://localhost:3000` (User: `admin`, Password retrieved from secret):
   ```bash
   kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($input))
   ```
3. Navigate to **Dashboards** > **New** > **Import** > Upload [`monitoring/grafana-dashboard.json`](monitoring/grafana-dashboard.json).

---

## 5. Port-Forward Reference Table

| Component | Port-Forward Command | Local URL | Default Credentials |
|---|---|---|---|
| **Grafana** | `kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80` | `http://localhost:3000` | `admin` / *(from secret)* |
| **Prometheus UI** | `kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090` | `http://localhost:9090` | None |
| **Alertmanager UI** | `kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-alertmanager 9093:9093` | `http://localhost:9093` | None |
| **Jaeger UI** | `kubectl port-forward -n monitoring svc/jaeger-query 16686:16686` | `http://localhost:16686` | None |
| **Robot Shop Web** | `kubectl port-forward -n robot-shop svc/web 8080:8080` | `http://localhost:8080` | None |

---

## 6. SRE Documentation & Incident Drills

### 6.1 Documentation Assets

- **[SLO & Error Budget Policy](slo/error-budget-policy.md)**: Four Golden Signals targets, multi-window burn rate alerts (14× critical, 6× warning), and mandatory team freeze actions.
- **[On-Call Runbook](runbook/runbook.md)**: Playbooks for Web errors, latency degradation, payment service outages, pod crash loops, and budget burn events.
- **[Blameless Postmortem Template](postmortem/postmortem-template.md)**: Standardized RCA format with a complete filled-in example (`INC-2026-037`).
- **[Architecture Specification](../docs/architecture.md)**: Comprehensive architectural reference diagram and network flows.

### 6.2 Conducting Incident Drills (Chaos Testing)

To validate alerts and runbook execution, run the following drill:

**Scenario: Payment Service Degradation Drill**
1. Inject network latency or introduce failing pod configuration:
   ```bash
   kubectl scale deployment payment -n robot-shop --replicas=0
   ```
2. Observe firing alerts:
   - Within 2m: `RobotShopCartPaymentDown` fires in Alertmanager and routes to Slack `#robot-shop-alerts`.
   - Within 5m: `RobotShopPaymentAvailabilityBreach` fires.
3. Follow the remediation steps in [`runbook/runbook.md` Section 3.3](runbook/runbook.md#33-robotshopcartpaymentdown).
4. Restore payment service:
   ```bash
   kubectl scale deployment payment -n robot-shop --replicas=1
   ```
5. Confirm resolution notice arrives in Slack and complete a test incident review using [`postmortem/postmortem-template.md`](postmortem/postmortem-template.md).
