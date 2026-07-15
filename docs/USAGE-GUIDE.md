# Usage Guide — Ai-Monitoring Stack

## What This Application Does

This is a **complete monitoring solution** running on a single AWS EC2 instance:

- **Grafana** — Beautiful dashboards for visualizing metrics and logs
- **Prometheus** — Collects and stores metrics (CPU, memory, HTTP requests)
- **Loki** — Collects and stores application logs
- **Node.js App** — Sample application generating logs and metrics
- **Node Exporter** — System-level metrics (CPU, memory, disk)

Everything runs in **Docker containers** and **auto-starts** on boot.

---

## Quick Access (after deployment)

| Service | URL | Login |
|---------|-----|-------|
| **Grafana** | `http://<YOUR_IP>:3001` | admin / admin123 |
| **Node.js App** | `http://<YOUR_IP>:3000` | No login |
| **Prometheus** | `http://<YOUR_IP>:9090` | No login |
| **App Health** | `http://<YOUR_IP>:3000/health` | No login |

---

## How to Get Your IP

### Option A: GitHub Actions output
After running `START` or `apply`, the workflow shows the IP in its output.

### Option B: AWS CLI
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text --region us-east-1
```

### Option C: AWS Console
1. Go to https://console.aws.amazon.com/ec2/
2. Click **Instances**
3. Find `grafana-loki-monitoring-server`
4. Copy the **Public IPv4 address**

---

## Using Grafana (Dashboards)

### Step 1: Open Grafana
```
http://<YOUR_IP>:3001
```

### Step 2: Login
- Username: `admin`
- Password: `admin123`

### Step 3: View Dashboards
1. Click the **Dashboards** icon (4 squares) in the left sidebar
2. Click a dashboard:
   - **Node.js Application Dashboard** — Shows HTTP request rates, latency, active connections, and application logs
   - **EC2 Infrastructure Dashboard** — Shows CPU, memory, disk usage, and network traffic

### Step 4: Explore Logs
1. Click the **Explore** icon (compass) in the left sidebar
2. Select **Loki** from the data source dropdown at the top
3. Enter: `{app="nodejs-app"}`
4. Click **Run query**
5. You'll see all application logs in real-time!

### Step 5: Generate Dashboard Data
Run these from your local machine to create activity:
```bash
IP=<YOUR_IP>
for i in $(seq 1 30); do
  curl -s http://$IP:3000/api/users > /dev/null
  curl -s http://$IP:3000/api/orders -X POST -H "Content-Type: application/json" -d '{"items":["test"]}' > /dev/null
  curl -s http://$IP:3000/api/error > /dev/null
  curl -s http://$IP:3000/api/slow > /dev/null
done
echo "Done! Refresh Grafana dashboards to see data."
```

---

## Using Prometheus (Metrics)

### Access
```
http://<YOUR_IP>:9090
```

### Check What's Being Monitored
1. Click **Status** → **Targets** in the top menu
2. You should see all targets as `UP` (green):
   - `prometheus` — Self-monitoring
   - `nodejs-app` — Application metrics
   - `node-exporter` — System metrics

### Run a Query
1. Type in the **Expression** box at the top
2. Click **Execute**
3. Switch between **Table** and **Graph** tabs

### Useful Queries

| Query | What it shows |
|-------|--------------|
| `up` | Which services are healthy |
| `rate(http_requests_total[5m])` | HTTP requests per second |
| `active_connections` | Current active connections |
| `process_resident_memory_bytes / 1024 / 1024` | App memory (MB) |
| `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Server CPU % |

---

## Using the Node.js App

### API Endpoints

| URL | Method | What it does |
|-----|--------|-------------|
| `http://<IP>:3000/` | GET | App info and available endpoints |
| `http://<IP>:3000/health` | GET | Health check (status, uptime) |
| `http://<IP>:3000/api/users` | GET | Returns sample user list |
| `http://<IP>:3000/api/orders` | POST | Creates an order (generates logs) |
| `http://<IP>:3000/api/error` | GET | Simulates error (test alerting) |
| `http://<IP>:3000/api/slow` | GET | Simulates slow response (1-3s) |
| `http://<IP>:3000/metrics` | GET | Raw Prometheus metrics |

### Examples

```bash
# Health check
curl http://<IP>:3000/health

# Create an order
curl -X POST http://<IP>:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"items":["laptop","mouse"],"total":1299.99}'

# Trigger error (for testing Grafana alerts)
curl http://<IP>:3000/api/error

# Test slow response
curl http://<IP>:3000/api/slow
```

---

## Viewing Logs (Loki via Grafana)

Loki collects all application and system logs. View them through Grafana:

1. Open Grafana → Click **Explore** (compass icon)
2. Select **Loki** data source
3. Use these queries:

| Query | Shows |
|-------|-------|
| `{app="nodejs-app"}` | All app logs |
| `{app="nodejs-app"} \|= "error"` | Error logs only |
| `{app="nodejs-app"} \|= "Order created"` | Order creation logs |
| `{app="nodejs-app"} \| json \| statusCode="500"` | HTTP 500 errors |
| `{job="syslog"}` | System logs |
| `{job="docker"}` | All Docker container logs |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Single EC2 Instance (t3.medium)                             │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Docker Containers:                                      │ │
│  │                                                           │ │
│  │  ┌─────────┐ ┌──────┐ ┌────────────┐ ┌──────────┐     │ │
│  │  │ Grafana │ │ Loki │ │ Prometheus │ │ Promtail │     │ │
│  │  │  :3001  │ │:3100 │ │   :9090    │ │          │     │ │
│  │  └─────────┘ └──────┘ └────────────┘ └──────────┘     │ │
│  │                                                           │ │
│  │  ┌──────────────┐  ┌──────────────┐                    │ │
│  │  │  Node.js App │  │ Node Exporter│                    │ │
│  │  │    :3000     │  │    :9100     │                    │ │
│  │  └──────────────┘  └──────────────┘                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  Auto-starts on boot via systemd + docker-compose             │
└─────────────────────────────────────────────────────────────┘

Data Flow:
  Node.js App → logs → Loki → Grafana (log dashboards)
  Node.js App → /metrics → Prometheus → Grafana (metric dashboards)
  EC2 System → Node Exporter → Prometheus → Grafana (infra dashboards)
```

---

## Security

| Port | Service | Who can access |
|------|---------|---------------|
| 22 | SSH | Your IP (or SSM — no SSH needed) |
| 3000 | Node.js App | Public |
| 3001 | Grafana | Public (password protected) |
| 9090 | Prometheus | Public |
| 3100 | Loki | Public (API only) |
| 9100 | Node Exporter | Public |

**Recommendation:** Restrict security group to your IP for production use.

---

## Docker Commands (inside EC2)

Connect via SSM or SSH, then:

```bash
# Check running containers
docker ps

# View all logs
cd /opt/monitoring-app && docker-compose logs --tail 50

# Restart all services
docker-compose restart

# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Rebuild Node.js app after code changes
docker-compose build nodejs-app && docker-compose up -d nodejs-app

# Check resource usage
docker stats --no-stream
```

---

## Monthly Cost

| Usage Pattern | Cost |
|--------------|------|
| Running 24/7 | ~$37/month |
| 12 hrs/day weekdays (auto schedule) | ~$23/month |
| Stopped (storage only) | ~$7/month |
| Destroyed | $0/month |
