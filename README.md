# Grafana + Loki + Node.js EC2 Monitoring Stack

A production-ready monitoring infrastructure deploying Grafana, Loki, Prometheus, and a Node.js application across 3 AWS EC2 instances with full observability, logging, and metrics collection.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS VPC (10.0.0.0/16)                           │
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │
│  │   EC2 Instance 1    │  │   EC2 Instance 2    │  │   EC2 Instance 3    │ │
│  │   (Monitoring)      │  │   (Application)     │  │   (Application)     │ │
│  │                     │  │                     │  │                     │ │
│  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │ │
│  │  │ Grafana :3001 │  │  │  │ Node.js :3000 │  │  │  │ Node.js :3000 │  │ │
│  │  │ Loki    :3100 │  │  │  │ Promtail      │  │  │  │ Promtail      │  │ │
│  │  │ Prometheus    │  │  │  │ Node Exporter │  │  │  │ Node Exporter │  │ │
│  │  │   :9090       │  │  │  │   :9100       │  │  │  │   :9100       │  │ │
│  │  │ Promtail      │  │  │  └───────────────┘  │  │  └───────────────┘  │ │
│  │  │ Node Exporter │  │  │                     │  │                     │ │
│  │  │   :9100       │  │  │                     │  │                     │ │
│  │  └───────────────┘  │  └─────────────────────┘  └─────────────────────┘ │
│  └─────────────────────┘                                                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                     Internet Gateway                                    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component      | Port | Description                              |
|----------------|------|------------------------------------------|
| Grafana        | 3001 | Visualization and dashboards             |
| Loki           | 3100 | Log aggregation system                   |
| Prometheus     | 9090 | Metrics collection and storage           |
| Node.js App    | 3000 | Application with logging and metrics     |
| Node Exporter  | 9100 | System-level metrics (CPU, memory, disk) |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js >= 18.0.0
- AWS CLI v2 (for EC2 deployment)
- Terraform >= 1.5.0 (for infrastructure provisioning)

### Local Development

```bash
# Start the monitoring stack locally
cd monitoring
./scripts/setup-monitoring.sh

# Or manually
docker-compose up -d

# Access services
# Grafana:    http://localhost:3001 (admin/admin123)
# Node.js:    http://localhost:3000
# Prometheus: http://localhost:9090
# Loki:       http://localhost:3100
```

### EC2 Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

## EC2 On/Off Toggle

### GitHub Actions (Recommended)

Use the **EC2 Toggle** workflow (`ec2-toggle.yml`) from the Actions tab:

1. Go to **Actions** → **EC2 Toggle**
2. Click **Run workflow**
3. Select action: `start`, `stop`, or `status`
4. Select instances: `all`, `monitoring-only`, `app-only`, `instance-1`, `instance-2`, `instance-3`

**Scheduled:**
- Auto-stop: Weekdays at 8:00 PM UTC
- Auto-start: Weekdays at 7:00 AM UTC

### CLI

```bash
# Start all instances
./scripts/ec2-control.sh start all

# Stop application instances only
./scripts/ec2-control.sh stop app

# Check status of a specific instance
./scripts/ec2-control.sh status 2

# Restart monitoring instance
./scripts/ec2-control.sh restart monitoring
```

## CI/CD Pipeline

The deployment pipeline (`.github/workflows/deploy.yml`) includes:

1. **Validate** - Terraform format check, validation, Node.js tests
2. **Build** - Docker image build and artifact creation
3. **Terraform Plan** - Infrastructure change preview
4. **Terraform Apply** - Deploy infrastructure (requires approval)
5. **Terraform Destroy** - Manual teardown option

Triggers:
- Push to `main` (paths: `terraform/`, `nodejs-app/`, `monitoring/`)
- Pull requests
- Manual dispatch (plan/apply/destroy)

## Required GitHub Secrets

| Secret                 | Description                          |
|------------------------|--------------------------------------|
| `AWS_ACCESS_KEY_ID`    | AWS IAM access key                   |
| `AWS_SECRET_ACCESS_KEY`| AWS IAM secret key                   |
| `AWS_KEY_PAIR_NAME`    | EC2 key pair name for SSH access     |

## API Endpoints

| Method | Endpoint      | Description                          |
|--------|---------------|--------------------------------------|
| GET    | `/`           | Application info and version         |
| GET    | `/health`     | Health check (status, uptime, id)    |
| GET    | `/api/users`  | Sample users list                    |
| POST   | `/api/orders` | Create order (returns random ID)     |
| GET    | `/api/error`  | Simulate error (for testing alerts)  |
| GET    | `/api/slow`   | Simulate slow response (1-3s delay)  |
| GET    | `/metrics`    | Prometheus metrics endpoint          |

## Project Structure

```
.
├── .github/workflows/      # CI/CD and EC2 toggle workflows
├── monitoring/
│   ├── dashboards/         # Grafana dashboard JSON files
│   ├── loki/               # Loki configuration
│   ├── prometheus/         # Prometheus configuration
│   ├── promtail/           # Promtail configuration
│   ├── provisioning/       # Grafana provisioning (datasources, dashboards)
│   └── docker-compose.yml  # Full monitoring stack
├── nodejs-app/
│   ├── src/                # Application source code
│   ├── Dockerfile          # Container image
│   └── package.json        # Dependencies
├── terraform/
│   ├── templates/          # User data scripts
│   ├── main.tf             # Provider and backend config
│   ├── vpc.tf              # VPC and networking
│   ├── ec2.tf              # EC2 instances
│   ├── security-groups.tf  # Security group rules
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
└── scripts/                # Utility scripts
```

## License

MIT
