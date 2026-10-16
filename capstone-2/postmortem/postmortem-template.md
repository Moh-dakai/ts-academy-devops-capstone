# Blameless Postmortem Template
## Robot Shop — Production Incident Review

---

> **Blameless Culture Commitment:** This postmortem is conducted in a blameless manner. The goal is to understand *what* happened and *why*, not to assign blame to individuals. People act with good intentions based on the information and tools available at the time. We improve systems and processes, not punish people.

---

## Incident Header

| Field | Value |
|-------|-------|
| **Incident ID** | `INC-YYYY-NNN` (e.g. INC-2026-042) |
| **Incident Title** | Brief description of the incident |
| **Date of Incident** | YYYY-MM-DD |
| **Incident Start** | HH:MM UTC |
| **Incident End (Resolved)** | HH:MM UTC |
| **Total Duration** | X hours Y minutes |
| **Severity** | P1 / P2 / P3 / P4 |
| **Postmortem Author** | `<Name>` |
| **Postmortem Date** | YYYY-MM-DD |
| **Status** | Draft / In Review / Complete |
| **Review Meeting Date** | YYYY-MM-DD |

---

## Executive Summary

> *2–3 sentences maximum. Describe what failed, how it impacted users, and what was done to resolve it. This should be understandable by non-technical stakeholders.*

`<Write the executive summary here. Example: "On [date], the Robot Shop payment service became unavailable for 47 minutes due to a misconfigured environment variable introduced in deployment v2.3.1. Approximately 1,200 customers were unable to complete purchases, resulting in an estimated $8,400 in lost revenue. The service was restored by rolling back to the previous deployment version.">`

---

## Impact

### User Impact

| Metric | Value |
|--------|-------|
| **Services Affected** | `e.g. Payment, Cart` |
| **Environments** | Production |
| **Users Affected** | `<Number and percentage of total user base>` |
| **Requests Failed** | `<Number of failed requests>` |
| **Error Rate at Peak** | `<e.g. 87% of payment requests>` |
| **Regions / Availability Zones** | `<e.g. eu-west-1>` |

### Business Impact

| Metric | Value |
|--------|-------|
| **Revenue Impact** | `$<estimated>` (or "Unknown") |
| **SLO Breach** | Yes / No |
| **Error Budget Consumed** | `<% of monthly budget>` |
| **Customer Complaints Received** | `<Number>` |
| **Support Tickets Created** | `<Number>` |
| **Status Page Updated** | Yes / No |

---

## Timeline

> *Chronological order of events. Be precise with timestamps (UTC). Include detection, investigation steps, key findings, mitigation attempts, and resolution.*

| Time (UTC) | Who | Event |
|------------|-----|-------|
| `HH:MM` | Automated | Prometheus alert `<AlertName>` fired |
| `HH:MM` | `<On-call SRE>` | PagerDuty page received; acknowledged within 5 min |
| `HH:MM` | `<On-call SRE>` | Posted `🔍 Investigating [alert] — @handle on it` to `#sre-incidents` |
| `HH:MM` | `<On-call SRE>` | Opened Grafana dashboard; confirmed elevated error rate |
| `HH:MM` | `<On-call SRE>` | Checked pod logs; found `<error message>` |
| `HH:MM` | `<On-call SRE>` | Escalated to Engineering Lead `<Name>` |
| `HH:MM` | `<Engineering Lead>` | Joined incident bridge; reviewed recent deployments |
| `HH:MM` | `<Engineering Lead>` | Identified deployment `v2.X.X` as likely cause |
| `HH:MM` | `<On-call SRE>` | Initiated rollback: `kubectl rollout undo deployment/<name>` |
| `HH:MM` | Automated | Error rate returned to baseline; alert resolved |
| `HH:MM` | `<On-call SRE>` | Posted resolution to `#sre-incidents` |
| `HH:MM` | `<On-call SRE>` | Status page updated to Operational |
| `HH:MM` | `<On-call SRE>` | Incident closed in PagerDuty |

---

## Root Cause Analysis

### Problem Statement

`<One sentence: precisely what failed and what was the immediate cause.>`

### 5 Whys Analysis

> *Start from the observable symptom and ask "why" five times to find the root cause.*

| # | Question | Answer |
|---|----------|--------|
| **Why 1** | Why did users see errors? | Because the payment service returned HTTP 500 errors |
| **Why 2** | Why did the payment service return 500 errors? | Because it could not connect to MySQL |
| **Why 3** | Why could it not connect to MySQL? | Because the `DB_HOST` environment variable was set to an incorrect value |
| **Why 4** | Why was `DB_HOST` set incorrectly? | Because the deployment ConfigMap was updated manually without review |
| **Why 5** | Why was it updated without review? | Because there was no PR review gate for ConfigMap changes in CI/CD |

**Root Cause:** `<State the root cause clearly. e.g. "ConfigMap changes could be deployed to production without a mandatory peer review, allowing a misconfiguration to go undetected.">`

### System / Process Contribution

`<Describe the system or process failure that enabled or amplified the incident. Focus on policies, tooling, monitoring gaps, etc.>`

---

## Contributing Factors

> *List factors that contributed to the incident occurring, its severity, or the time to detect/resolve it. These are NOT root causes but they made the situation worse or harder to handle.*

- [ ] `<Factor 1: e.g. No canary deployment — change went straight to 100% of traffic>`
- [ ] `<Factor 2: e.g. Alert took 8 minutes to fire after the error started — increased MTTD>`
- [ ] `<Factor 3: e.g. Runbook did not include steps for MySQL connectivity issues>`
- [ ] `<Factor 4: e.g. On-call engineer was unfamiliar with the payment service architecture>`
- [ ] `<Factor 5: e.g. Status page was not updated promptly, causing confusion for customer support>`

---

## What Went Well

> *Acknowledge things the team did right, or systems that worked as designed. This reinforces good practices.*

- [ ] `<e.g. Alert fired correctly and within expected thresholds>`
- [ ] `<e.g. On-call engineer acknowledged within 3 minutes (under 5-minute SLA)>`
- [ ] `<e.g. Rollback completed in under 4 minutes with no data loss>`
- [ ] `<e.g. Clear communication maintained in #sre-incidents throughout the incident>`
- [ ] `<e.g. PagerDuty escalation worked correctly when secondary was needed>`

---

## What Went Wrong

> *Honest assessment of what failed — at the system, process, or tooling level (NOT individual blame).*

- [ ] `<e.g. No automated validation of ConfigMap values in CI/CD pipeline>`
- [ ] `<e.g. MTTD was 8 minutes — alert threshold was too conservative>`
- [ ] `<e.g. Runbook lacked MySQL connection troubleshooting steps>`
- [ ] `<e.g. Deployment went to 100% of pods simultaneously with no canary>`
- [ ] `<e.g. Status page update took 20 minutes — no clear owner for this task>`

---

## Action Items

> *Concrete, assigned, time-boxed improvements. SMART: Specific, Measurable, Achievable, Relevant, Time-bound.*

| # | Action Item | Owner | Due Date | Priority | Status |
|---|-------------|-------|----------|----------|--------|
| 1 | Add ConfigMap schema validation step in CI/CD pipeline | `<Name>` | `YYYY-MM-DD` | P1 | Open |
| 2 | Add MySQL connectivity check to payment readiness probe | `<Name>` | `YYYY-MM-DD` | P1 | Open |
| 3 | Reduce alert window from 10m to 5m for payment error rate | `<Name>` | `YYYY-MM-DD` | P2 | Open |
| 4 | Add MySQL connection troubleshooting to runbook section 3.3 | `<Name>` | `YYYY-MM-DD` | P2 | Open |
| 5 | Implement canary deployment strategy for payment service | `<Name>` | `YYYY-MM-DD` | P2 | Open |
| 6 | Document and assign status page update ownership | `<Name>` | `YYYY-MM-DD` | P3 | Open |
| 7 | Conduct game day drill for MySQL failure scenario | `<Name>` | `YYYY-MM-DD` | P3 | Open |

---

## Lessons Learned

> *Key insights the team takes away. These should influence future design decisions, processes, and training.*

1. **`<Lesson 1 Title>`:** `<Description. e.g. "ConfigMap changes carry the same risk as code changes and must go through the same PR review process.">`

2. **`<Lesson 2 Title>`:** `<Description. e.g. "Readiness probes should validate all critical dependencies (DB, message queue) before a pod is marked ready.">`

3. **`<Lesson 3 Title>`:** `<Description. e.g. "Our runbooks need to be tested quarterly to ensure they are accurate and actionable under stress.">`

4. **`<Lesson 4 Title>`:** `<Description. e.g. "MTTD can be reduced by setting tighter alert thresholds for revenue-critical services.">`

---

## Detection & Response Metrics

| Metric | Definition | Value |
|--------|-----------|-------|
| **MTTD** (Mean Time to Detect) | Time from incident start to alert fire | `X minutes` |
| **MTTA** (Mean Time to Acknowledge) | Time from alert to on-call acknowledgement | `X minutes` |
| **MTTI** (Mean Time to Investigate) | Time from ack to root cause identification | `X minutes` |
| **MTTR** (Mean Time to Resolve) | Time from incident start to full resolution | `X minutes` |
| **MTTF** (Mean Time to Failure) | Time since last production incident | `X days` |

---

## Appendix

### A. Relevant Logs

```
<Paste relevant log snippets here. Sanitize any sensitive data (passwords, tokens, PII).>
```

### B. Relevant Metrics / Graphs

> *Reference Grafana snapshot URLs or attach screenshots here.*

- Grafana snapshot: `<URL or description>`
- Error rate graph: `<URL or description>`
- Latency graph: `<URL or description>`

### C. Relevant Alerts Fired

| Alert Name | Fired At | Resolved At | Duration |
|------------|----------|-------------|----------|
| `<AlertName>` | `HH:MM UTC` | `HH:MM UTC` | `X min` |

### D. Related Incidents

| Incident ID | Date | Description | Link |
|-------------|------|-------------|------|
| `<INC-ID>` | `YYYY-MM-DD` | Similar MySQL connectivity issue | `<Link>` |

### E. Communication Log

| Time (UTC) | Channel | Message Summary |
|------------|---------|-----------------|
| `HH:MM` | `#sre-incidents` | Initial investigation notice |
| `HH:MM` | `#status-updates` | Customer-facing status update |
| `HH:MM` | `#sre-incidents` | Resolution notice |
| `HH:MM` | Email | External SLA notification (if applicable) |

---

---

# Example Postmortem: Payment Service 500 Errors (v2.3.1)

> *This is a filled-in example demonstrating how to use the template above.*

---

## Incident Header

| Field | Value |
|-------|-------|
| **Incident ID** | `INC-2026-037` |
| **Incident Title** | Payment service returning HTTP 500 errors after deployment v2.3.1 |
| **Date of Incident** | 2026-10-08 |
| **Incident Start** | 14:22 UTC |
| **Incident End (Resolved)** | 15:09 UTC |
| **Total Duration** | 47 minutes |
| **Severity** | P1 |
| **Postmortem Author** | Alex Chen (SRE) |
| **Postmortem Date** | 2026-10-09 |
| **Status** | Complete |
| **Review Meeting Date** | 2026-10-10 |

---

## Executive Summary

On 2026-10-08, the Robot Shop payment service became unavailable for 47 minutes due to a misconfigured `DB_HOST` environment variable introduced in deployment v2.3.1. The incorrect hostname caused all payment pod instances to fail their database connections on startup, returning HTTP 500 to all checkout requests. Approximately 1,200 users were unable to complete purchases. The service was restored by rolling back to v2.3.0, and all pending orders were re-processed from the RabbitMQ queue with no data loss.

---

## Impact

### User Impact

| Metric | Value |
|--------|-------|
| **Services Affected** | Payment, Cart (cascading) |
| **Environments** | Production (eu-west-1) |
| **Users Affected** | ~1,200 (estimated 18% of active users during incident window) |
| **Requests Failed** | ~14,400 payment requests |
| **Error Rate at Peak** | 100% of payment requests |
| **Regions / AZs** | eu-west-1a, eu-west-1b |

### Business Impact

| Metric | Value |
|--------|-------|
| **Revenue Impact** | ~$8,400 (estimated avg order value × failed transactions) |
| **SLO Breach** | Yes — Payment availability dropped to 0% for 47 min |
| **Error Budget Consumed** | 32% of monthly error budget in a single incident |
| **Customer Complaints** | 23 via support chat |
| **Support Tickets** | 18 created |
| **Status Page Updated** | Yes (14:38 UTC — 16 min after incident start) |

---

## Timeline

| Time (UTC) | Who | Event |
|------------|-----|-------|
| 14:15 | CI/CD | Deployment v2.3.1 rolled out to `robot-shop` namespace (100% traffic) |
| 14:22 | Prometheus | Alert `RobotShopCartPaymentDown` fired; payment error rate = 100% |
| 14:24 | PagerDuty | On-call SRE Alex Chen paged |
| 14:26 | Alex Chen | Acknowledged page; posted to `#sre-incidents`: "🔍 Investigating payment 500s — @alex on it" |
| 14:27 | Alex Chen | Opened Grafana dashboard; confirmed payment error rate 100%, cart error rate 67% |
| 14:29 | Alex Chen | Ran `kubectl logs -n robot-shop -l service=payment --tail=100`; saw "dial tcp: lookup mysql-prod.robot-shop.svc.cluster.local: no such host" |
| 14:31 | Alex Chen | Ran `kubectl describe deployment payment -n robot-shop`; found `DB_HOST=mysql-prod` (incorrect, should be `mysql`) |
| 14:33 | Alex Chen | Checked git log; found `DB_HOST` changed in ConfigMap in v2.3.1 without PR review |
| 14:35 | Alex Chen | Escalated to Engineering Lead Sarah Park |
| 14:36 | Sarah Park | Joined call; confirmed rollback is correct action |
| 14:37 | Alex Chen | Initiated rollback: `kubectl rollout undo deployment/payment -n robot-shop` |
| 14:38 | Alex Chen | Updated status page to "Investigating — Checkout issues" |
| 14:41 | Prometheus | Payment error rate dropping; rollback pods coming online |
| 14:45 | Prometheus | Payment error rate returned to < 0.1%; alert resolved |
| 14:47 | Alex Chen | Confirmed all payment pods running v2.3.0 |
| 14:50 | Alex Chen | RabbitMQ queue processing resumed; pending orders re-queued |
| 15:05 | Alex Chen | Updated status page to "Resolved" |
| 15:09 | Alex Chen | Incident closed in PagerDuty; MTTR = 47 minutes |

---

## Root Cause Analysis

### Problem Statement

The payment service crashed on startup because `DB_HOST` in the production ConfigMap was set to `mysql-prod` (a non-existent hostname) instead of `mysql`, preventing all payment pods from connecting to the MySQL database.

### 5 Whys Analysis

| # | Question | Answer |
|---|----------|--------|
| **Why 1** | Why did users get 500 errors on checkout? | Because the payment service was returning 500 errors for all requests |
| **Why 2** | Why was payment returning 500 errors? | Because payment pods could not connect to MySQL on startup |
| **Why 3** | Why could they not connect to MySQL? | Because `DB_HOST` was set to `mysql-prod` — a hostname that doesn't exist in the cluster |
| **Why 4** | Why was `DB_HOST` set to a wrong value? | A developer manually updated the ConfigMap for v2.3.1 thinking `mysql-prod` was the correct internal service name |
| **Why 5** | Why did a wrong ConfigMap value make it to production? | ConfigMap changes were applied directly via `kubectl apply` in the CI/CD pipeline without any schema validation or peer review step |

**Root Cause:** ConfigMap changes were not subject to the same peer review and validation gates as application code changes. A typo in `DB_HOST` was not caught before it reached production.

---

## Contributing Factors

- [x] **No canary deployment**: v2.3.1 deployed to 100% of payment pods simultaneously, causing total service failure rather than a partial degradation
- [x] **Alert delay**: The alert fired 7 minutes after deployment, meaning 100% of payment requests during that window failed without any alert
- [x] **Status page lag**: Status page was updated 16 minutes into the incident — customer support received complaints before the page reflected the issue
- [x] **No startup validation**: Payment service did not have a readiness probe that validated database connectivity before marking the pod ready

---

## What Went Well

- [x] Prometheus alert fired correctly once the 5-minute window elapsed
- [x] Alex acknowledged the PagerDuty page within 2 minutes (well under the 5-minute SLA)
- [x] Root cause was identified within 5 minutes of investigation using pod logs
- [x] Rollback completed in under 10 minutes with no data loss — RabbitMQ preserved pending orders
- [x] Clear communication maintained in `#sre-incidents` with timestamps throughout

---

## What Went Wrong

- [x] ConfigMap changes had no validation or review gate in the CI/CD pipeline
- [x] `DB_HOST` value was not validated against the expected format/hostname
- [x] No canary deployment — all pods received the broken config simultaneously
- [x] No readiness probe for DB connectivity — pods started "ready" even though they couldn't serve requests
- [x] Status page update was delayed (16 min) — ownership unclear during incident

---

## Action Items

| # | Action Item | Owner | Due Date | Priority | Status |
|---|-------------|-------|----------|----------|--------|
| 1 | Add ConfigMap schema validation in CI pipeline (fail build if `DB_HOST` doesn't match `mysql`) | Sarah Park | 2026-10-18 | P1 | ✅ Done |
| 2 | Add MySQL TCP readiness probe to payment deployment | Alex Chen | 2026-10-18 | P1 | ✅ Done |
| 3 | Implement canary deployment (10% → 50% → 100%) for payment service | DevOps Team | 2026-10-31 | P1 | In Progress |
| 4 | Add alert for payment error rate > 1% firing within 2 minutes (not 5) | Alex Chen | 2026-10-20 | P2 | Open |
| 5 | Assign explicit status page update ownership in runbook | Alex Chen | 2026-10-18 | P2 | ✅ Done |
| 6 | Add ConfigMap change checklist to deployment runbook | Sarah Park | 2026-10-25 | P2 | Open |
| 7 | Schedule quarterly game day: MySQL failure simulation | SRE Team | 2026-11-15 | P3 | Open |

---

## Lessons Learned

1. **Infrastructure config = code:** ConfigMap changes must go through the same PR review gate as application code. We will add a required CODEOWNERS review for all `k8s/` directory changes.

2. **Test your dependencies at startup:** Readiness probes should validate all critical dependencies. A payment pod that can't reach its database should never be marked "Ready."

3. **Canary everything revenue-critical:** The payment service is too business-critical to roll out 100% at once. Even a 5-minute canary phase at 10% traffic would have caught this.

4. **Own your status page:** Every incident needs one named person responsible for keeping the status page current. This must be explicit in the runbook and incident process.

---

## Detection & Response Metrics

| Metric | Value |
|--------|-------|
| **MTTD** | 7 minutes (alert fired 7 min after deployment) |
| **MTTA** | 2 minutes (Alex ack'd within 2 min of page) |
| **MTTI** | 5 minutes (root cause in logs within 5 min of investigation) |
| **MTTR** | 47 minutes (total incident duration) |
| **MTTF** | 23 days (last P1 was INC-2026-029 on 2026-09-15) |

---

## Appendix

### A. Relevant Logs

```
# Payment pod logs at 14:29 UTC
2026-10-08T14:22:17Z ERROR Failed to connect to database: dial tcp: lookup mysql-prod.robot-shop.svc.cluster.local on 10.100.0.10:53: no such host
2026-10-08T14:22:17Z FATAL Cannot establish database connection, exiting.
2026-10-08T14:22:18Z ERROR Failed to connect to database: dial tcp: lookup mysql-prod.robot-shop.svc.cluster.local on 10.100.0.10:53: no such host
```

### B. Relevant Metrics

- Grafana snapshot: `https://grafana.example.com/dashboard/snapshot/abc123`
- Payment error rate peaked at 100% from 14:22 to 14:45 UTC
- Error budget impact: 47 min of downtime = 32% of monthly budget consumed

### C. Alerts Fired

| Alert Name | Fired At | Resolved At | Duration |
|------------|----------|-------------|----------|
| `RobotShopCartPaymentDown` | 14:22 UTC | 14:45 UTC | 23 min |
| `RobotShopWebErrorBudgetCritical` | 14:28 UTC | 14:50 UTC | 22 min |
| `ErrorBudgetBurning` | 14:30 UTC | 14:55 UTC | 25 min |

### D. Related Incidents

| Incident ID | Date | Description |
|-------------|------|-------------|
| INC-2026-029 | 2026-09-15 | MySQL pod OOMKilled due to memory limit too low |
| INC-2026-018 | 2026-08-22 | Payment failing due to RabbitMQ queue backlog |

---

*This postmortem was completed blameless. The findings reflect system and process gaps, not individual failures. All action items have assigned owners and due dates.*
