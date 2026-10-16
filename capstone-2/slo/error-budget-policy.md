# SLO & Error Budget Policy
## Robot Shop — Production Services

---

**Document Version:** 1.0  
**Effective Date:** 2026-10-16  
**Owner:** DevOps / SRE Team  
**Review Cadence:** Monthly (SLO review), Quarterly (target adjustment)  
**Classification:** Internal

---

## Table of Contents

1. [Purpose & Scope](#1-purpose--scope)
2. [SLO Definition Table](#2-slo-definition-table)
3. [Error Budget Calculation](#3-error-budget-calculation)
4. [Error Budget Policy](#4-error-budget-policy)
5. [Burn Rate Alerts](#5-burn-rate-alerts)
6. [Slack Alert Configuration](#6-slack-alert-configuration)
7. [Review Cadence](#7-review-cadence)
8. [Stakeholder Sign-Off](#8-stakeholder-sign-off)

---

## 1. Purpose & Scope

This document defines the **Service Level Objectives (SLOs)** and **Error Budget Policy** for the Robot Shop application running in production on Amazon EKS. It establishes:

- Measurable reliability targets for each critical service
- How error budgets are calculated and tracked
- What actions the team must take as error budgets are consumed
- Alert thresholds and escalation procedures

**In Scope:** Web frontend, Catalogue service, Cart service, Payment service  
**Out of Scope:** Internal batch jobs, non-customer-facing services, development/staging environments

---

## 2. SLO Definition Table

### 2.1 Service Level Indicators (SLIs) and Targets

| Service | SLI Type | SLI Definition | SLO Target | Measurement Window | Error Budget |
|---------|-----------|----------------|------------|-------------------|--------------|
| **Web** | Availability | `(HTTP 2xx + 3xx responses) / total HTTP requests` | ≥ 99.5% | 30-day rolling | 0.5% (≈ 3.6 hrs/month) |
| **Web** | Latency (P99) | `99th percentile of HTTP request duration` | < 500 ms | 30-day rolling | — |
| **Web** | Error Rate | `HTTP 5xx responses / total HTTP requests` | < 0.5% | 30-day rolling | — |
| **Catalogue** | Availability | `(HTTP 2xx responses) / total HTTP requests` | ≥ 99.5% | 30-day rolling | 0.5% (≈ 3.6 hrs/month) |
| **Catalogue** | Latency (P99) | `99th percentile of catalogue API response time` | < 500 ms | 30-day rolling | — |
| **Catalogue** | Error Rate | `HTTP 5xx responses / total HTTP requests` | < 0.5% | 30-day rolling | — |
| **Cart** | Availability | `(successful cart operations) / total cart requests` | ≥ 99.5% | 30-day rolling | 0.5% (≈ 3.6 hrs/month) |
| **Cart** | Latency (P99) | `99th percentile of cart API response time` | < 500 ms | 30-day rolling | — |
| **Cart** | Error Rate | `HTTP 5xx + Redis errors / total cart requests` | < 0.5% | 30-day rolling | — |
| **Payment** | Availability | `(successful payment transactions) / total payment requests` | ≥ 99.5% | 30-day rolling | 0.5% (≈ 3.6 hrs/month) |
| **Payment** | Latency (P99) | `99th percentile of payment processing time` | < 500 ms | 30-day rolling | — |
| **Payment** | Error Rate | `HTTP 5xx + failed transactions / total payment requests` | < 0.5% | 30-day rolling | — |

### 2.2 Prometheus SLI Queries

```promql
# Web Availability SLI (30-day)
sum(rate(http_requests_total{service="web", code!~"5.."}[30d]))
  / sum(rate(http_requests_total{service="web"}[30d]))

# Web P99 Latency
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{service="web"}[5m])) by (le))

# Web Error Rate
sum(rate(http_requests_total{service="web", code=~"5.."}[30d]))
  / sum(rate(http_requests_total{service="web"}[30d]))
```

---

## 3. Error Budget Calculation

### 3.1 Formula

```
Error Budget (%) = 100% - SLO Target (%)
Error Budget (minutes/month) = (100% - SLO%) × 30 days × 24 hrs × 60 min
Error Budget Remaining (%) = 1 - (Error Rate over window / Error Budget %)
```

### 3.2 Worked Example — 99.5% Availability SLO

| Metric | Value |
|--------|-------|
| SLO Target | 99.5% |
| Error Budget Percentage | 0.5% |
| Total minutes in 30 days | 43,200 minutes |
| **Allowed downtime / month** | **216 minutes ≈ 3.6 hours** |
| Total requests (example) | 10,000,000 |
| **Allowed failed requests** | **50,000 requests** |

### 3.3 Current Budget Consumption (Prometheus)

```promql
# Error budget remaining percentage for web service
1 - (
  sum(rate(http_requests_total{service="web", code=~"5.."}[30d]))
  / sum(rate(http_requests_total{service="web"}[30d]))
) / 0.005
```

---

## 4. Error Budget Policy

The following policy defines mandatory actions at each error budget consumption threshold. **These are not optional** — they are binding agreements between the Product and SRE teams.

### 4.1 Threshold Definitions

| Budget Remaining | Status | Trigger Condition |
|-----------------|--------|-------------------|
| > 75% | 🟢 **Healthy** | Normal operations |
| 75% → 50% | 🟡 **Caution** | Heightened monitoring required |
| 50% → 25% | 🟠 **Warning** | Feature freeze in effect |
| 25% → 0% | 🔴 **Critical** | Reliability work only |
| 0% (exhausted) | 🚨 **Breach** | Full freeze + postmortem |

---

### 4.2 75% Remaining — Caution

**Trigger:** Error budget consumption exceeds 25% of monthly allowance

**Required Actions:**
- [ ] SRE team notified via Slack `#sre-alerts` channel
- [ ] Monitor error rate and latency dashboards more frequently (every 2 hours)
- [ ] **No new high-risk deployments** (database schema changes, architectural changes) without explicit SRE approval
- [ ] Review recent deployments for correlation with error increase
- [ ] Engineering lead informed of budget status at daily standup

**Who:** On-call SRE  
**Escalation:** Team Lead if no improvement within 48 hours

---

### 4.3 50% Remaining — Warning (Feature Freeze)

**Trigger:** Error budget consumption exceeds 50% of monthly allowance

**Required Actions:**
- [ ] **Freeze all non-critical feature deployments** — only bug fixes and security patches allowed
- [ ] Mandatory incident review meeting (Engineering Lead + SRE + Product Manager)
- [ ] Identify top 3 reliability risks from the past 30 days
- [ ] Create and prioritize reliability improvement tickets in backlog
- [ ] Increase alert sensitivity (reduce thresholds by 20%)
- [ ] Daily error budget report sent to `#engineering-leads` Slack channel
- [ ] Deployment freeze documented and communicated to all engineers

**Who:** Engineering Lead + SRE Team Lead  
**Escalation:** VP Engineering notified

---

### 4.4 25% Remaining — Critical (Reliability Only)

**Trigger:** Error budget consumption exceeds 75% of monthly allowance

**Required Actions:**
- [ ] **ALL feature development halted** — reliability work only
- [ ] Weekly executive review meeting (CTO / VP Eng + Engineering Lead + SRE)
- [ ] Immediate root cause analysis for top error contributors
- [ ] Every deployment (even hotfixes) requires SRE sign-off
- [ ] Rollback plan must be documented and tested before any deployment
- [ ] Real-time error budget dashboard reviewed at start of every working day
- [ ] On-call rotation increased to 2 SREs simultaneously
- [ ] Customer success team notified of potential SLA risk

**Who:** VP Engineering + SRE Team Lead + Engineering Lead  
**Escalation:** CTO if no improvement within 72 hours

---

### 4.5 0% Remaining — Budget Exhausted (Full Freeze)

**Trigger:** Error budget fully consumed; SLO breached for the month

**Required Actions:**
- [ ] **Complete deployment freeze** — no changes to production except emergency security patches (require CTO approval)
- [ ] Mandatory **blameless postmortem** must be completed and reviewed before any new deployments are approved
- [ ] Customer-facing status page updated if user impact occurred
- [ ] SLA review — assess if contractual obligations were breached
- [ ] Emergency reliability sprint initiated (next sprint dedicated entirely to reliability)
- [ ] All engineers notified of freeze via email + Slack
- [ ] Post-incident review with entire engineering team within 5 business days
- [ ] Updated SLO policy reviewed if budget is consistently exhausted

**Who:** CTO + VP Engineering + All Engineering Leads  
**Review:** Full postmortem review required; deployment moratorium until SLO tracking shows sustained recovery

---

## 5. Burn Rate Alerts

**Burn rate** measures how quickly the error budget is being consumed relative to the expected rate. A burn rate of 1x means budget is being consumed at exactly the rate that would exhaust it at the end of the window. A burn rate of 14x means the budget would be exhausted in 1/14th of the remaining window.

### 5.1 Multi-Window Burn Rate Alert Table

| Alert Name | Short Window | Long Window | Burn Rate | Severity | Meaning | Action |
|------------|-------------|------------|-----------|----------|---------|--------|
| `ErrorBudgetCritical` | 5 min | 1 hour | ≥ 14× | 🔴 Critical | Budget exhausted in ~2 hours | Page on-call immediately |
| `ErrorBudgetWarning` | 30 min | 6 hours | ≥ 6× | 🟠 Warning | Budget exhausted in ~5 hours | Notify team, investigate |
| `ErrorBudgetSlow` | 2 hours | 24 hours | ≥ 3× | 🟡 Info | Budget at risk this week | Review in next standup |
| `AvailabilityBreach` | — | 30 min | — | 🔴 Critical | SLO target currently breached | Immediate investigation |

### 5.2 Burn Rate Formulas

```promql
# 1-hour burn rate for web service
(
  sum(rate(http_requests_total{service="web", code=~"5.."}[1h]))
  / sum(rate(http_requests_total{service="web"}[1h]))
) / 0.005

# 6-hour burn rate for web service
(
  sum(rate(http_requests_total{service="web", code=~"5.."}[6h]))
  / sum(rate(http_requests_total{service="web"}[6h]))
) / 0.005
```

### 5.3 Alert Condition for Multi-Window Detection

Multi-window alerts reduce false positives by requiring the burn rate to be elevated in BOTH a short and long window simultaneously:

```promql
# Critical: 1h burn rate > 14x AND 5m burn rate > 14x
(burn_rate_1h > 14) and (burn_rate_5m > 14)

# Warning: 6h burn rate > 6x AND 30m burn rate > 6x  
(burn_rate_6h > 6) and (burn_rate_30m > 6)
```

---

## 6. Slack Alert Configuration

The following `PrometheusRule` manifest implements the burn rate alerting policy. Full YAML is maintained in `capstone-2/monitoring/slo-alerts.yaml`.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: robot-shop-error-budget-alerts
  namespace: monitoring
  labels:
    app: robot-shop
    team: devops
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
    - name: robot-shop.slo
      interval: 30s
      rules:
        # ── Web Service: Critical burn rate (1h window, 14× burn) ──────────────
        - alert: RobotShopWebErrorBudgetCritical
          expr: |
            (
              sum(rate(http_requests_total{
                namespace="robot-shop",
                service="web",
                code=~"5.."
              }[1h]))
              /
              sum(rate(http_requests_total{
                namespace="robot-shop",
                service="web"
              }[1h]))
            ) / 0.005 > 14
          for: 2m
          labels:
            severity: critical
            service: web
            team: devops
          annotations:
            summary: "Robot Shop Web: Critical error budget burn rate"
            description: >
              The web service is burning its error budget at {{ $value | printf "%.1f" }}×
              the sustainable rate. At this pace, the monthly error budget will be
              exhausted in approximately {{ div 720 $value | printf "%.0f" }} hours.
            runbook_url: "https://github.com/your-org/ts-academy/blob/main/capstone-2/runbook/runbook.md#robotshopwebhigherrorrate"
            dashboard_url: "http://grafana.monitoring.svc/d/robot-shop-slo"

        # ── Web Service: Warning burn rate (6h window, 6× burn) ───────────────
        - alert: RobotShopWebErrorBudgetWarning
          expr: |
            (
              sum(rate(http_requests_total{
                namespace="robot-shop",
                service="web",
                code=~"5.."
              }[6h]))
              /
              sum(rate(http_requests_total{
                namespace="robot-shop",
                service="web"
              }[6h]))
            ) / 0.005 > 6
          for: 15m
          labels:
            severity: warning
            service: web
            team: devops
          annotations:
            summary: "Robot Shop Web: Elevated error budget burn rate"
            description: >
              The web service is burning its error budget at {{ $value | printf "%.1f" }}×
              the sustainable rate over the past 6 hours.
            runbook_url: "https://github.com/your-org/ts-academy/blob/main/capstone-2/runbook/runbook.md#robotshopwebhigherrorrate"
```

### 6.1 Alertmanager Slack Route Configuration

```yaml
# alertmanager-config.yaml (relevant section)
route:
  receiver: "default"
  group_by: ["alertname", "service", "severity"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
        team: devops
      receiver: "slack-critical"
      repeat_interval: 1h
    - match:
        severity: warning
        team: devops
      receiver: "slack-warning"
      repeat_interval: 4h

receivers:
  - name: "slack-critical"
    slack_configs:
      - api_url: "<SLACK_WEBHOOK_URL_CRITICAL>"
        channel: "#sre-incidents"
        icon_emoji: ":fire:"
        title: "🚨 [CRITICAL] {{ .CommonAnnotations.summary }}"
        text: |
          *Alert:* {{ .CommonAnnotations.summary }}
          *Description:* {{ .CommonAnnotations.description }}
          *Runbook:* {{ .CommonAnnotations.runbook_url }}
          *Dashboard:* {{ .CommonAnnotations.dashboard_url }}
        send_resolved: true

  - name: "slack-warning"
    slack_configs:
      - api_url: "<SLACK_WEBHOOK_URL_WARNING>"
        channel: "#sre-alerts"
        icon_emoji: ":warning:"
        title: "⚠️ [WARNING] {{ .CommonAnnotations.summary }}"
        text: |
          *Alert:* {{ .CommonAnnotations.summary }}
          *Description:* {{ .CommonAnnotations.description }}
          *Runbook:* {{ .CommonAnnotations.runbook_url }}
        send_resolved: true
```

---

## 7. Review Cadence

### 7.1 Monthly SLO Review

**Frequency:** First Monday of each month  
**Attendees:** SRE Team Lead, Engineering Leads, Product Manager  
**Agenda:**
1. Review previous month's SLO achievement per service
2. Review error budget consumption trends
3. Review incidents that consumed error budget
4. Update action items from previous review
5. Confirm next month's deployment schedule vs. budget health

**Outputs:** Monthly SLO Report (stored in `docs/slo-reports/YYYY-MM.md`)

### 7.2 Quarterly Target Adjustment

**Frequency:** End of each quarter (Q1: March, Q2: June, Q3: September, Q4: December)  
**Attendees:** CTO/VP Eng, Engineering Leads, SRE Team, Product  
**Agenda:**
1. Review quarterly SLO trends
2. Assess if targets are too aggressive (constant breach) or too lenient (never consumed)
3. Adjust SLO targets as needed — requires consensus and 30-day notice before change
4. Review and update this policy document

**Criteria for Adjustment:**
- SLO target raised: Error budget was never < 50% in any month of the quarter
- SLO target lowered: Error budget was exhausted in 2+ months of the quarter (after investing in reliability)

---

## 8. Stakeholder Sign-Off

By signing below, stakeholders acknowledge that they have read, understood, and agree to the SLO targets and Error Budget Policy defined in this document.

| Role | Name | Signature | Date |
|------|------|-----------|------|
| CTO / VP Engineering | `<NAME>` | ____________ | ________ |
| Engineering Lead | `<NAME>` | ____________ | ________ |
| SRE Team Lead | `<NAME>` | ____________ | ________ |
| Product Manager | `<NAME>` | ____________ | ________ |
| Head of Customer Success | `<NAME>` | ____________ | ________ |

---

*This document is reviewed monthly and updated quarterly. For questions, contact the SRE team at `#sre-team` on Slack.*
