# Workflow Guide — Ai-Monitoring

## Overview

This project has 3 GitHub Actions workflows to manage your infrastructure:

| # | Workflow | Purpose | Frequency |
|---|---------|---------|-----------|
| 1 | **Deploy Infrastructure** | Create/destroy EC2 instances & infra | One-time setup |
| 2 | **EC2 Start / Stop** | Turn instances ON/OFF (one click) | Daily |
| 3 | **EC2 Toggle** | Advanced start/stop with target selection | Optional |

---

## Prerequisites

### 1. GitHub Secrets (must be configured)

Go to: **Settings → Secrets and variables → Actions**

| Secret | Value | Required |
|--------|-------|----------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key (AKIA...) | Yes |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | Yes |
| `AWS_KEY_PAIR_NAME` | Name of your EC2 key pair | Yes |

### 2. Merge all PRs

Before running workflows, merge any open PRs in the repository.

---

## First-Time Setup (Run Once)

### Step 1: Create Infrastructure

```
GitHub → Actions → Deploy Infrastructure → Run workflow
  Branch: main
  Action: apply
  → Click "Run workflow"
```

**What happens:**
1. Creates VPC, subnets, security groups
2. Creates 3 EC2 instances (1 monitoring + 2 app servers)
3. Creates Elastic IPs
4. Instances auto-install Docker, clone repo, start all services
5. Takes ~8-10 minutes total

### Step 2: Wait 5 minutes

After the workflow completes, wait 5 minutes for the EC2 user-data script to:
- Install Docker & Docker Compose
- Clone the Ai-Monitoring repository
- Build the Node.js Docker image
- Start Grafana, Loki, Prometheus, and the Node.js app

### Step 3: Access your services

Check the workflow output for IP addresses, then open:

| Service | URL | Login |
|---------|-----|-------|
| Grafana | `http://<MONITORING_IP>:3001` | admin / admin123 |
| Node.js App | `http://<ANY_IP>:3000` | No login needed |
| Prometheus | `http://<MONITORING_IP>:9090` | No login needed |

---

## Daily Usage

### Start Instances (Morning)

```
GitHub → Actions → EC2 Start / Stop → Run workflow
  Action: START All Instances
  → Click "Run workflow"
```

Wait 2-3 minutes for instances to boot and Docker to auto-start. Then access Grafana/App.

### Stop Instances (Evening — Save Cost)

```
GitHub → Actions → EC2 Start / Stop → Run workflow
  Action: STOP All Instances
  → Click "Run workflow"
```

Compute charges are paused immediately. EBS storage charges still apply (~$0.25/day).

### Check Status

```
GitHub → Actions → EC2 Start / Stop → Run workflow
  Action: STATUS Check
  → Click "Run workflow"
```

Shows a table with instance names, IDs, state (running/stopped), and IPs.

---

## Advanced Usage (EC2 Toggle)

For more granular control over specific instances:

```
GitHub → Actions → EC2 Toggle → Run workflow
  Action: start / stop / status
  Target: all / monitoring-only / app-only / instance-1 / instance-2 / instance-3
  → Click "Run workflow"
```

### Use cases:
- Stop only app servers but keep monitoring running
- Restart a specific instance that's having issues
- Start only the monitoring server to check dashboards

---

## Workflow Execution Diagram

```
╔══════════════════════════════════════════════════════════════╗
║                    FIRST TIME SETUP                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   Deploy Infrastructure → apply                              ║
║         │                                                    ║
║         ▼                                                    ║
║   [Creates VPC + 3 EC2 + EIPs]                              ║
║         │                                                    ║
║         ▼                                                    ║
║   EC2 user-data runs automatically:                          ║
║   • Install Docker                                           ║
║   • Clone repo from GitHub                                   ║
║   • Build Node.js image                                      ║
║   • docker-compose up -d                                     ║
║         │                                                    ║
║         ▼                                                    ║
║   ✅ All services running!                                   ║
║   Grafana :3001 | App :3000 | Prometheus :9090              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║                    DAILY WORKFLOW                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   ┌─────────────┐         ┌──────────────┐                 ║
║   │   MORNING   │         │   EVENING    │                 ║
║   │             │         │              │                 ║
║   │ EC2 Start / │         │ EC2 Start /  │                 ║
║   │ Stop →      │         │ Stop →       │                 ║
║   │ START All   │         │ STOP All     │                 ║
║   │             │         │              │                 ║
║   │ Wait 2 min  │         │ Instant      │                 ║
║   │     ↓       │         │     ↓        │                 ║
║   │ Access apps │         │ Cost saved!  │                 ║
║   └─────────────┘         └──────────────┘                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║                 CODE UPDATE (Automatic)                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   Push code to main branch                                   ║
║   (changes in nodejs-app/ or monitoring/)                    ║
║         │                                                    ║
║         ▼                                                    ║
║   Deploy Infrastructure auto-triggers:                       ║
║   • Validate Terraform                                       ║
║   • Build Docker image                                       ║
║   • Run Terraform plan                                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║                  TEAR DOWN (Delete All)                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║   Deploy Infrastructure → destroy                            ║
║         │                                                    ║
║         ▼                                                    ║
║   All EC2 instances terminated                               ║
║   All networking resources deleted                           ║
║   No more AWS charges!                                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Quick Reference

| I want to... | Do this |
|--------------|---------|
| Create infrastructure | Actions → Deploy Infrastructure → `apply` |
| Start instances | Actions → EC2 Start / Stop → `START All Instances` |
| Stop instances | Actions → EC2 Start / Stop → `STOP All Instances` |
| Check status | Actions → EC2 Start / Stop → `STATUS Check` |
| Stop only app servers | Actions → EC2 Toggle → `stop` → `app-only` |
| Delete everything | Actions → Deploy Infrastructure → `destroy` |
| View pipeline logs | Actions → Click on the workflow run → View logs |

---

## Troubleshooting

### "Error acquiring the state lock"
A previous run left a stale lock. Fix:
```bash
aws dynamodb delete-item \
  --table-name ai-monitoring-tf-locks \
  --key '{"LockID":{"S":"ai-monitoring-tfstate-496251222247/terraform.tfstate"}}' \
  --region us-east-1
```

### "S3 bucket does not exist"
The Terraform state bucket needs to be created first:
```bash
aws s3api create-bucket --bucket ai-monitoring-tfstate-496251222247 --region us-east-1
```

### Workflow fails at "Terraform Validate"
Check if you have syntax errors in `.tf` files. Run locally:
```bash
cd terraform && terraform init -backend=false && terraform validate
```

### Instances are running but can't access services
- Wait 5 minutes after start (Docker needs time to boot)
- Check security group allows your IP on ports 3000, 3001, 9090
- SSH in and check: `docker ps` and `docker-compose logs`

### App shows "unhealthy" after start
Services take 2-3 minutes to fully start after EC2 boot. Wait and retry.

---

## Cost Management

### Running 24/7 (3 instances):
- ~$98/month

### With daily start/stop (12 hrs, weekdays only):
- ~$56/month

### Stopped (only storage):
- ~$8/month (just EBS volumes)

### Destroyed (nothing running):
- $0/month

**Tip:** Always run `STOP All Instances` when you're done for the day!

---

## Automatic Scheduling (Optional)

After merging PR #1, the EC2 Toggle workflow includes automatic schedules:

| Schedule | Action | Days |
|----------|--------|------|
| 7:00 AM UTC | Auto-START | Monday - Friday |
| 8:00 PM UTC | Auto-STOP | Monday - Friday |
| 9:00 AM UTC | Auto-STOP | Saturday - Sunday |

This means instances automatically turn on in the morning and off at night — no manual action needed!
