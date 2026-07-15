# Grafana + Loki + Node.js EC2 Monitoring Stack

A complete **AI-powered monitoring solution** running on a single AWS EC2 instance with automated deployment, Docker auto-start, snapshot backups, and one-click infrastructure control via GitHub Actions.

## Features

- **Grafana** — Dashboards for metrics and log visualization
- **Loki** — Log aggregation (view app logs in Grafana)
- **Prometheus** — Metrics collection and alerting
- **Node.js App** — Sample application with built-in logging and metrics
- **Docker Auto-Start** — All services start automatically on EC2 boot/reboot
- **CI/CD Pipeline** — Terraform infrastructure + Docker build via GitHub Actions
- **EC2 Start/Stop** — One-click on/off with cost-saving auto-schedule
- **Snapshot & Restore** — Backup and restore infrastructure with zero data loss
- **SSM Access** — Connect to EC2 without SSH keys
- **Approval Gates** — Safety confirmation for destructive actions

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  AWS EC2 (Single Instance - t3.medium)                           │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Docker Containers (auto-start on boot):                     │ │
│  │                                                               │ │
│  │  ┌─────────┐ ┌──────┐ ┌────────────┐ ┌──────────┐         │ │
│  │  │ Grafana │ │ Loki │ │ Prometheus │ │ Promtail │         │ │
│  │  │  :3001  │ │:3100 │ │   :9090    │ │          │         │ │
│  │  └─────────┘ └──────┘ └────────────┘ └──────────┘         │ │
│  │                                                               │ │
│  │  ┌──────────────┐  ┌──────────────┐                        │ │
│  │  │  Node.js App │  │ Node Exporter│                        │ │
│  │  │    :3000     │  │    :9100     │                        │ │
│  │  └──────────────┘  └──────────────┘                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  systemd monitoring-stack.service → docker-compose up -d          │
└─────────────────────────────────────────────────────────────────┘

Data Flow:
  App → Winston Logger → Loki → Grafana (Logs)
  App → /metrics → Prometheus → Grafana (Metrics)
  EC2 → Node Exporter → Prometheus → Grafana (Infrastructure)
```

---

## Services & Ports

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| Grafana | 3001 | `http://<IP>:3001` | Dashboards & log viewer |
| Node.js App | 3000 | `http://<IP>:3000` | Sample application |
| Prometheus | 9090 | `http://<IP>:9090` | Metrics query UI |
| Loki | 3100 | `http://<IP>:3100` | Log API (view via Grafana) |
| Node Exporter | 9100 | `http://<IP>:9100` | System metrics |

**Grafana Login:** admin / admin123

---

## Project Structure

```
Ai-Monitoring/
├── .github/workflows/
│   ├── deploy.yml              # Infrastructure deploy/destroy pipeline
│   ├── ec2-toggle.yml          # EC2 Start/Stop with auto-schedule
│   ├── ec2-snapshot.yml        # Snapshot backup & restore
│   └── ec2-start-stop.yml      # Simple one-click start/stop
├── nodejs-app/
│   ├── src/
│   │   ├── index.js            # Express server (7 endpoints)
│   │   ├── logger.js           # Winston + Loki transport
│   │   └── metrics.js          # Prometheus metrics (prom-client)
│   ├── Dockerfile              # Node 22 Alpine container
│   └── package.json
├── monitoring/
│   ├── docker-compose.yml      # All 6 services
│   ├── loki/loki-config.yml    # Loki storage config
│   ├── prometheus/prometheus.yml # Scrape targets
│   ├── promtail/promtail-config.yml # Log collection
│   ├── dashboards/             # Pre-built Grafana dashboards
│   └── provisioning/           # Auto-configured datasources
├── terraform/
│   ├── main.tf                 # Provider + S3 backend
│   ├── ec2.tf                  # Single EC2 + IAM + EIP
│   ├── vpc.tf                  # VPC + subnet + IGW
│   ├── security-groups.tf      # Ports 22,3000,3001,9090,3100,9100
│   ├── outputs.tf              # IP, URLs, SSM command
│   ├── variables.tf            # Configurable variables
│   └── templates/user-data.sh  # Auto-setup script (Docker + app)
├── scripts/
│   ├── ec2-control.sh          # CLI start/stop/status
│   ├── health-check.sh         # Service health checker
│   └── setup-monitoring.sh     # Manual setup helper
├── docs/
│   ├── WORKFLOW-GUIDE.md       # Step-by-step workflow guide
│   └── USAGE-GUIDE.md         # How to use the application
└── README.md
```

---

## GitHub Actions Workflows

| Workflow | Actions | Approval | Schedule |
|---------|---------|----------|----------|
| **Deploy Infrastructure** | plan, apply, apply-from-snapshot, destroy | Yes (destroy/restore) | On push to main |
| **EC2 Start / Stop** | START, STOP, STATUS | No | Auto: 7AM start, 8PM stop (Mon-Fri) |
| **EC2 Snapshot & Restore** | Create, List, Restore, Delete old | Yes (restore/delete) | Auto: daily 2AM backup |
| **EC2 Start/Stop (Simple)** | START All, STOP All, STATUS | No | — |

---

## Quick Start

### Prerequisites

- AWS account with CLI configured
- GitHub account with this repo
- GitHub Secrets configured:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_KEY_PAIR_NAME` | EC2 key pair name |

### Deploy (one-time)

1. Go to **Actions** → **Deploy Infrastructure** → **Run workflow**
2. Select: `apply`
3. Click **Run workflow**
4. Wait 8-10 minutes (Terraform + EC2 boot + Docker setup)
5. Open: `http://<IP>:3001` → Grafana is live!

### Daily Usage

| Action | Steps |
|--------|-------|
| **Start** | Actions → EC2 Start / Stop → `START` |
| **Stop** | Actions → EC2 Start / Stop → `STOP` |
| **Check** | Actions → EC2 Start / Stop → `STATUS` |

### Backup & Restore

| Action | Steps |
|--------|-------|
| **Backup** | Actions → EC2 Snapshot & Restore → `Create Snapshot` |
| **Destroy safely** | Actions → Deploy Infrastructure → `destroy` + type 'yes' (auto-snapshots first!) |
| **Restore** | Actions → Deploy Infrastructure → `apply-from-snapshot` + type 'yes' |

---

## Node.js API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | App info + available endpoints |
| `/health` | GET | Health status, uptime, instance ID |
| `/api/users` | GET | Sample user list (generates logs) |
| `/api/orders` | POST | Create order (generates logs) |
| `/api/error` | GET | Simulate error (test alerting) |
| `/api/slow` | GET | Simulate slow response (1-3s) |
| `/metrics` | GET | Prometheus metrics |

---

## Grafana Dashboards

Two pre-built dashboards included:

### Node.js Application Dashboard
- HTTP Requests per Second
- Request Duration (p95 latency)
- Active Connections
- Application Logs (from Loki)
- Error Logs

### EC2 Infrastructure Dashboard
- CPU Usage
- Memory Usage
- Disk Usage
- Network Traffic (receive/transmit)
- System Logs

---

## What Happens on EC2 Boot

The user-data script runs automatically when EC2 starts:

```
[1/8] Install system packages
[2/8] Install Docker & Docker Compose
[3/8] Install SSM Agent (no SSH key needed)
[4/8] Clone this repo from GitHub
[5/8] Build Node.js Docker image
[6/8] docker-compose up -d (ALL services start)
[7/8] Create systemd service (auto-restart on reboot)
[8/8] Health check all services
```

**Result:** All services running within 5 minutes of instance creation. No manual SSH or setup needed.

---

## Connect to EC2 (No SSH Key Required)

### Via GitHub Actions
```
Actions → EC2 Connect & Debug → Select instance → Type command → Run
```

### Via AWS CLI
```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" \
  --query 'Reservations[].Instances[].InstanceId' --output text --region us-east-1)

aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

---

## Cost

| Pattern | Monthly Cost |
|---------|-------------|
| Running 24/7 | ~$37 |
| 12 hrs/day weekdays (auto schedule) | ~$23 |
| Stopped (storage only) | ~$7 |
| Destroyed | $0 |

---

## Terraform Backend

| Resource | Name |
|----------|------|
| S3 Bucket | `ai-monitoring-tfstate-496251222247` |
| DynamoDB Table | `ai-monitoring-tf-locks` |
| Region | `us-east-1` |

---

## Documentation

- **[docs/WORKFLOW-GUIDE.md](docs/WORKFLOW-GUIDE.md)** — Complete step-by-step workflow instructions
- **[docs/USAGE-GUIDE.md](docs/USAGE-GUIDE.md)** — How to use Grafana, Prometheus, Loki, and the Node.js app

---

## License

MIT
