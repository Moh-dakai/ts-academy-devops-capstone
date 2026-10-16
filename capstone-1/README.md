# Capstone 1: Automated CI/CD Pipeline & EKS Deployment
## Production-Grade Kubernetes Delivery for Example Voting App

---

## 1. Project Overview

Capstone 1 demonstrates an automated, secure, and production-ready CI/CD delivery lifecycle for the multi-tier **Example Voting App**.

The infrastructure and deployment encompass:
- **Hardened Container Images**: Multi-stage builds, non-root users (`appuser` UID 1001), minimal base images (`python:3.11-slim-bookworm`, `node:20-slim`, `dotnet/runtime:7.0`), pinned versions, and proactive `.dockerignore` files.
- **Infrastructure as Code (IaC)**: Terraform provisioning an Amazon EKS cluster with managed node groups, dedicated IAM roles, autoscaling, and VPC networking.
- **Declarative Packaging (Helm)**: A production Helm chart with liveness/readiness probes, resource requests/limits, services, and parameterized configuration.
- **Automated CI/CD (GitHub Actions)**: Automated pipeline executing unit tests, vulnerability scanning with Trivy (failing on HIGH/CRITICAL issues), Docker image building with Git SHA tags, and zero-downtime deployment to Amazon EKS via Helm.

---

## 2. Architecture & Data Flow

```
                      DEVELOPER WORKFLOW
                   git push to main branch
                              │
                              ▼
                 ┌───────────────────────────┐
                 │       GITHUB ACTIONS      │
                 │ 1. Run Tests (Python)     │
                 │ 2. Security Scan (Trivy)  │
                 │ 3. Build & Tag (SHA)      │
                 │ 4. Push to Docker Hub     │
                 │ 5. Helm Upgrade EKS       │
                 └──────────────┬────────────┘
                                │
                                ▼
                   ┌────────────────────────┐
                   │    DOCKER HUB REGISTRY │
                   └────────────┬───────────┘
                                │ Helm pull
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                   AMAZON EKS (Namespace: voting-app)             │
│                                                                  │
│   ┌───────────────┐     ┌───────────────┐    ┌───────────────┐  │
│   │ vote (Python) │     │ result (Node) │    │  worker (.NET)│  │
│   │ Port 80 (NLB) │     │ Port 80 (NLB) │    │  (Internal)   │  │
│   └───────┬───────┘     └───────┬───────┘    └───────┬───────┘  │
│           │                     │                    │          │
│           │ writes              │ reads              │ worker   │
│           ▼                     │                    ▼ reads/w  │
│   ┌───────────────┐             │            ┌───────────────┐  │
│   │ Redis (Queue) │◄────────────┘            │ PostgreSQL DB │  │
│   │ Port 6379     │                          │ Port 5432     │  │
│   └───────────────┘                          └───────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Directory Layout

```
capstone-1/
├── .github/
│   └── workflows/
│       └── ci-cd.yml               # GitHub Actions CI/CD Pipeline
├── helm/
│   └── voting-app/
│       ├── Chart.yaml              # Chart metadata
│       ├── values.yaml             # Configurable parameters & replicas
│       └── templates/
│           ├── _helpers.tpl        # Name & label helpers
│           ├── vote-deployment.yaml
│           ├── vote-service.yaml
│           ├── result-deployment.yaml
│           ├── result-service.yaml
│           ├── worker-deployment.yaml
│           ├── redis-deployment.yaml
│           └── postgres-deployment.yaml
├── terraform/
│   ├── versions.tf                 # Terraform & AWS provider requirements
│   ├── variables.tf                # Cluster & node configuration
│   ├── main.tf                     # EKS, VPC, Subnets, IAM roles
│   └── outputs.tf                  # Cluster endpoints & kubeconfig helpers
├── vote/
│   ├── Dockerfile                  # Hardened Python container
│   └── .dockerignore
├── result/
│   ├── Dockerfile                  # Hardened Node.js container
│   └── .dockerignore
└── worker/
    ├── Dockerfile                  # Multi-stage .NET 7 container
    └── .dockerignore
```

---

## 4. Prerequisites

Before getting started, make sure you have installed:
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with adequate IAM rights (`aws configure`)
- [Terraform](https://www.terraform.io/) (>= 1.6)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm v3](https://helm.sh/)
- [Docker](https://www.docker.com/) & a Docker Hub account
- [Trivy](https://github.com/aquasecurity/trivy) (optional, for local image scanning)

---

## 5. Setup & Deployment Guide

### Step 1: Provision Amazon EKS Cluster via Terraform

```bash
cd capstone-1/terraform

# Initialize Terraform plugins
terraform init

# Plan infrastructure changes
terraform plan -out=tfplan

# Apply and provision VPC + EKS cluster (takes ~15 minutes)
terraform apply tfplan

# Authenticate kubectl against newly created cluster
aws eks --region eu-west-1 update-kubeconfig --name voting-app-cluster
```

### Step 2: Local Vulnerability Scanning with Trivy

Verify your images meet security compliance before pushing to your registry:

```bash
# Build local images
docker build -t voting-app-vote:local ./vote
docker build -t voting-app-result:local ./result
docker build -t voting-app-worker:local ./worker

# Run Trivy vulnerability scan
trivy image --severity HIGH,CRITICAL voting-app-vote:local
trivy image --severity HIGH,CRITICAL voting-app-result:local
trivy image --severity HIGH,CRITICAL voting-app-worker:local
```

### Step 3: Configure GitHub Secrets

Navigate to your GitHub Repository > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**:

| Secret Name | Description | Example / Note |
|---|---|---|
| `DOCKERHUB_USERNAME` | Your Docker Hub account username | `mydevopsuser` |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token (Read/Write) | `dckr_pat_xxx` |
| `AWS_ACCESS_KEY_ID` | IAM User access key with EKS permissions | `AKIAXXXXXXXXXXXXXXXX` |
| `AWS_SECRET_ACCESS_KEY`| IAM User secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS Deployment Region | `eu-west-1` |

### Step 4: Trigger CI/CD Pipeline

Push your changes to the `main` branch:

```bash
git add .
git commit -m "feat: complete hardened CI/CD pipeline and Helm deployment"
git push origin main
```

The pipeline in `.github/workflows/ci-cd.yml` will automatically:
1. Run automated tests.
2. Execute a Trivy repository security scan.
3. Build and tag the images using both `latest` and `${{ github.sha }}`.
4. Push images to Docker Hub.
5. Execute a zero-downtime rolling update via `helm upgrade --install`.

---

## 6. Manual Helm Operations & Rollback

### Deploy / Upgrade Manually

```bash
helm upgrade --install voting-app ./helm/voting-app \
  --namespace voting-app \
  --create-namespace \
  --set image.tag=latest \
  --wait
```

### Inspect Deployment Status

```bash
helm status voting-app -n voting-app
kubectl get pods,svc -n voting-app
```

### Rollback Procedures

If an issue is detected in production after deployment, initiate an instant rollback:

```bash
# Check rollout history
helm history voting-app -n voting-app

# Roll back to the previous stable revision (e.g. Revision 1)
helm rollback voting-app 1 -n voting-app

# Verify pod status during rollback
kubectl rollout status deployment/voting-app-vote -n voting-app
kubectl rollout status deployment/voting-app-result -n voting-app
```

---

## 7. Teardown / Cleanup

To avoid ongoing AWS infrastructure charges after evaluation:

```bash
# 1. Uninstall Helm release
helm uninstall voting-app -n voting-app

# 2. Destroy EKS Cluster and VPC
cd capstone-1/terraform
terraform destroy -auto-approve
```
