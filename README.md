# 🚀 AWS API Gateway Blue/Green Deployment

[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Lambda](https://img.shields.io/badge/Compute-Lambda-FF9900?logo=aws-lambda&logoColor=white)](https://aws.amazon.com/lambda/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade, zero-downtime deployment pipeline using **blue/green strategy** on AWS — leveraging API Gateway dual stages, Lambda alias weighting, and fully automated rollout via GitHub Actions and Terraform.

---

## 📐 Architecture Overview

![System Architecture](./System%20Architecture%20Overview.png)


The system implements a classic blue/green deployment model where:

- **Blue** = Live production environment (stable, serving 100% of traffic)
- **Green** = Candidate environment (new release, validated before promotion)

Traffic is shifted gradually using **Lambda alias weighting** — starting at 10% to green, monitoring CloudWatch metrics, and promoting to 100% only when health thresholds are met.

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 🔵🟢 **Blue/Green Deployments** | Zero-downtime releases with instant rollback capability |
| ⚖️ **Canary Traffic Shifting** | Gradual 0% → 10% → 100% Lambda alias weighting |
| 📊 **Automated Validation** | CloudWatch alarms gate promotion — no human approval needed |
| 🏗️ **Infrastructure as Code** | Entire stack declared in Terraform; reproducible in any region |
| 🔄 **CI/CD Pipeline** | GitHub Actions orchestrates build, deploy, and promote stages |
| 🗄️ **Shared Data Layer** | DynamoDB + S3 shared between both environments — no data drift |

---

## 🏗️ Architecture Deep Dive

### Traffic Flow

```
Public Clients
     │
     ▼
Route 53 (DNS)
     │
     ▼
API Gateway — Single REST API, dual stages
   ┌────────┴────────┐
   ▼                 ▼
Blue Stage        Green Stage
(Production)      (Candidate)
   │                 │
   ▼                 ▼
Lambda           Lambda
(v1.0.0)         (v2.0.0)
   └────────┬────────┘
            ▼
   Shared Data Layer
   (DynamoDB + S3)
```

### Component Breakdown

#### 🌐 API Gateway
- Single REST API with **two isolated stages**: `blue` (production) and `green` (candidate)
- Each stage maps to a dedicated Lambda alias, enabling independent versioning
- Stage variables control which Lambda alias is invoked per environment

#### ⚡ Lambda (Alias-Based Versioning)
- **Blue alias** → `v1.0.0` — the stable, battle-tested release
- **Green alias** → `v2.0.0` — the new candidate under validation
- Lambda **alias routing weights** enable the canary shift without any DNS or infrastructure changes

#### 📊 CloudWatch (Observability & Gate)
- Metrics and alarms monitor error rates, latency (p99), and throttles on both environments
- The promotion pipeline reads alarm state — if green is unhealthy, the shift halts and rolls back automatically

#### 🔄 GitHub Actions (CI/CD)
- Triggers on push to `main`
- Runs: build → unit tests → `terraform apply` → deploy to green → canary shift → validate → promote
- On failure at any stage: auto-rollback to blue, alarm fired, PR comment posted

#### 🏗️ Terraform (IaC)
- Manages all AWS resources: API Gateway, Lambda functions/aliases, IAM roles, CloudWatch alarms, Route 53, S3 (TF state), DynamoDB
- Remote state stored in S3 with DynamoDB locking
- Modular structure for reusability across environments

#### 🗄️ Shared Data Layer (DynamoDB + S3)
- Both blue and green Lambdas share the **same DynamoDB tables and S3 buckets**
- Schema migrations are handled as backwards-compatible, non-breaking changes — a prerequisite for this deployment model

---

## 🔁 Deployment Lifecycle

```
1. Developer pushes to main
        │
        ▼
2. GitHub Actions: Build & Test
        │
        ▼
3. Terraform Apply
   (provisions green Lambda v2.0.0)
        │
        ▼
4. Deploy to Green Stage
   (API GW green stage → Lambda green alias)
        │
        ▼
5. Canary Shift: Blue 100% → Green 10%
   (Lambda alias weight updated)
        │
        ▼
6. CloudWatch Metric Validation (~5 min window)
        │
   ┌────┴────┐
   ▼         ▼
HEALTHY   UNHEALTHY
   │         │
   ▼         ▼
Promote   Rollback
Green→100%  Blue stays
```

---

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Main CI/CD pipeline
│       └── rollback.yml        # Manual rollback trigger
├── terraform/
│   ├── main.tf                 # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── api-gateway/        # API GW + stages config
│   │   ├── lambda/             # Function + alias + versioning
│   │   ├── cloudwatch/         # Alarms + dashboards
│   │   └── data-layer/         # DynamoDB + S3 resources
│   └── backend.tf              # S3 remote state config
├── src/
│   └── handler/                # Lambda function source code
│       ├── index.js
│       └── package.json
├── scripts/
│   ├── shift-traffic.sh        # Lambda alias weight updater
│   └── validate-metrics.sh     # CloudWatch alarm checker
├── System_Architecture_Overview.png
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions
- [Terraform](https://www.terraform.io/downloads) >= 1.5
- [Node.js](https://nodejs.org/) >= 18 (for Lambda source)
- GitHub repository secrets configured (see below)

### Required AWS IAM Permissions

The deploying IAM role/user needs permissions for:
`lambda:*`, `apigateway:*`, `cloudwatch:*`, `dynamodb:*`, `s3:*`, `route53:*`, `iam:PassRole`

### GitHub Secrets Setup

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_REGION` | Target AWS region (e.g. `us-east-1`) |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |

### Local Setup

```bash
# Clone the repository
git clone https://github.com/your-username/your-repo.git
cd your-repo

# Initialize Terraform
cd terraform
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="region=$AWS_REGION"

# Preview infrastructure changes
terraform plan

# Deploy infrastructure
terraform apply
```

### Manual Traffic Shift

```bash
# Shift 10% traffic to green (canary)
./scripts/shift-traffic.sh --blue 90 --green 10

# Validate metrics (waits 5 min, checks alarms)
./scripts/validate-metrics.sh

# Full promotion
./scripts/shift-traffic.sh --blue 0 --green 100

# Emergency rollback
./scripts/shift-traffic.sh --blue 100 --green 0
```

---

## 📊 Observability

CloudWatch dashboards track the following per environment (blue/green):

- **Error Rate** — 5xx / total requests (alarm threshold: > 1%)
- **Latency p99** — end-to-end response time (alarm threshold: > 2000ms)
- **Lambda Throttles** — concurrency limit breaches
- **Lambda Duration** — execution time trends
- **DynamoDB Read/Write Capacity** — consumed vs. provisioned units

---

## 🔐 Security Considerations

- Lambda functions run with **least-privilege IAM roles** (separate roles per alias)
- API Gateway endpoints protected via **IAM authorization** or **API keys** (configurable)
- Terraform state encrypted at rest in S3, access controlled via bucket policy
- Secrets managed via **AWS Secrets Manager** — never hardcoded
- CloudTrail enabled for full audit trail of API calls

---

## 🧠 Design Decisions

**Why a single API Gateway with dual stages instead of two separate APIs?**
Keeping a single API avoids DNS TTL propagation delays during cutover. Stage variables make the routing declarative and auditable.

**Why Lambda alias weighting over Route 53 weighted routing?**
Lambda alias weights shift traffic at the compute layer — below DNS — enabling sub-second rollbacks without waiting for TTL expiry and without clients needing to renegotiate connections.

**Why share DynamoDB/S3 between blue and green?**
Duplicating data stores introduces drift and synchronisation complexity. Shared data requires stricter migration discipline (backwards-compatible schemas) but eliminates an entire class of data-consistency bugs.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

