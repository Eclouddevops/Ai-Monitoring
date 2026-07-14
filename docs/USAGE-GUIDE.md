# Usage Guide — Ai-Monitoring Stack

## Table of Contents
- [After Deployment — How to Access](#after-deployment--how-to-access)
- [Service URLs & Ports](#service-urls--ports)
- [Using Grafana](#using-grafana)
- [Using the Node.js Application](#using-the-nodejs-application)
- [Viewing Logs in Grafana (Loki)](#viewing-logs-in-grafana-loki)
- [Prometheus Metrics](#prometheus-metrics)
- [EC2 On/Off Control](#ec2-onoff-control)
- [SSH Access](#ssh-access)
- [Architecture](#architecture)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)

---

## After Deployment — How to Access

Once you run the pipeline with `apply` (Actions → Deploy Infrastructure → Run workflow → `apply`), 3 EC2 instances will be created.

### Get the IP Addresses

After terraform apply completes, check the outputs:

```
Outputs:
  monitoring_server_ip = "54.x.x.x"
  instance_public_ips  = ["54.x.x.x", "3.x.x.x", "18.x.x.x"]
  grafana_url          = "http://54.x.x.x:3001"
```

**Or via AWS Console:**
1. Go to: https://console.aws.amazon.com/ec2/
2. Region: **us-east-1**
3. Look for instances named: `grafana-loki-monitoring-instance-1/2/3`

**Or via CLI:**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PublicIpAddress,State.Name]' \
  --output table --region us-east-1
```

---

## Service URLs & Ports

| Service | URL | Port | Credentials |
|---------|-----|------|-------------|
| **Grafana** (Dashboards) | `http://<MONITORING_IP>:3001` | 3001 | admin / admin123 |
| **Prometheus** (Metrics) | `http://<MONITORING_IP>:9090` | 9090 | No auth |
| **Loki** (Logs API) | `http://<MONITORING_IP>:3100` | 3100 | No auth |
| **Node.js App** | `http://<ANY_IP>:3000` | 3000 | No auth |
| **Node Exporter** | `http://<ANY_IP>:9100/metrics` | 9100 | No auth |

> **Note:** Replace `<MONITORING_IP>` with Instance 1's public IP, and `<ANY_IP>` with any instance's public IP.

---

## Using Grafana

### Login
1. Open browser: `http://<MONITORING_IP>:3001`
2. Username: **admin**
3. Password: **admin123**
4. (Optional: Change password on first login)

### Pre-Built Dashboards
Go to **Dashboards** in the left sidebar. Two dashboards are included:

#### 1. Node.js Application Dashboard
- HTTP Requests per Second
- Request Duration (p95 latency)
- Active Connections (gauge)
- Application Logs (from Loki)
- Error Logs

#### 2. EC2 Infrastructure Dashboard
- CPU Usage per instance
- Memory Usage per instance
- Disk Usage
- Network Traffic (receive/transmit)
- System Logs

### Adding Custom Dashboards
1. Click **+** → **New Dashboard**
2. Click **Add visualization**
3. Select data source: **Prometheus** (metrics) or **Loki** (logs)
4. Write your query and save

---

## Using the Node.js Application

The app runs on port **3000** on all instances. Use these endpoints to generate logs and test monitoring:

### Health Check
```bash
curl http://<APP_IP>:3000/health
```
Response:
```json
{
  "status": "healthy",
  "uptime": 1234.56,
  "instanceId": "instance-1",
  "timestamp": "2026-07-14T10:00:00.000Z",
  "version": "1.0.0"
}
```

### App Info
```bash
curl http://<APP_IP>:3000/
```

### Get Users (generates info logs)
```bash
curl http://<APP_IP>:3000/api/users
```

### Create Order (generates logs with order ID)
```bash
curl -X POST http://<APP_IP>:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"items":["laptop","mouse"],"total":1299.99}'
```

### Simulate Error (test error alerting in Grafana)
```bash
curl http://<APP_IP>:3000/api/error
```

### Simulate Slow Response (test latency monitoring)
```bash
curl http://<APP_IP>:3000/api/slow
```

### Prometheus Metrics
```bash
curl http://<APP_IP>:3000/metrics
```

### Generate Traffic (load test)
```bash
# Run 100 requests to generate dashboard data
for i in $(seq 1 100); do
  curl -s http://<APP_IP>:3000/api/users > /dev/null
  curl -s http://<APP_IP>:3000/health > /dev/null
  curl -s -X POST http://<APP_IP>:3000/api/orders \
    -H "Content-Type: application/json" \
    -d "{\"items\":[\"item-$i\"],\"total\":$i}" > /dev/null
done
echo "Done! Check Grafana dashboards now."
```

---

## Viewing Logs in Grafana (Loki)

### Basic Log Viewing
1. In Grafana → Click **Explore** (compass icon in left sidebar)
2. Select **Loki** as the data source (top dropdown)
3. Enter a query and click **Run query**

### Useful Loki Queries

| Query | Description |
|-------|-------------|
| `{app="nodejs-app"}` | All application logs |
| `{app="nodejs-app"} \|= "error"` | Only error logs |
| `{app="nodejs-app"} \|= "Order created"` | Order creation logs |
| `{app="nodejs-app"} \| json \| statusCode="500"` | HTTP 500 errors |
| `{app="nodejs-app"} \| json \| duration > "1000ms"` | Slow requests (>1s) |
| `{instance="instance-1"}` | Logs from specific instance |
| `{job="syslog"}` | System logs |
| `{job="docker"}` | Docker container logs |

### Log Stream Labels
- `app` — Application name (nodejs-app)
- `environment` — Environment (dev/production)
- `instance` — Instance ID (instance-1, instance-2, instance-3)
- `job` — Log source (docker, syslog, auth)

---

## Prometheus Metrics

### Access Prometheus UI
Open: `http://<MONITORING_IP>:9090`

### Useful PromQL Queries

| Query | Description |
|-------|-------------|
| `rate(http_requests_total[5m])` | Request rate per second |
| `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | p95 latency |
| `active_connections` | Current active connections |
| `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | CPU usage % |
| `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | Memory usage % |
| `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}` | Disk free % |

### Targets
Check scrape targets at: `http://<MONITORING_IP>:9090/targets`
- prometheus (self)
- nodejs-app:3000
- node-exporter:9100

---

## EC2 On/Off Control

### Via GitHub Actions (Recommended)
1. Go to: **Actions** → **EC2 Toggle** (or **Infrastructure On/Off Control** after merging PR #1)
2. Click **"Run workflow"**
3. Select:
   - **Action**: `start`, `stop`, or `status`
   - **Target**: `all`, `monitoring-only`, `app-only`, `instance-1/2/3`
4. Click **"Run workflow"**

### Via AWS CLI
```bash
# Get instance IDs
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text --region us-east-1

# Stop all instances (save cost at night)
aws ec2 stop-instances --instance-ids i-xxx i-yyy i-zzz --region us-east-1

# Start all instances
aws ec2 start-instances --instance-ids i-xxx i-yyy i-zzz --region us-east-1

# Check status
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress]' \
  --output table --region us-east-1
```

### Automatic Schedule (after merging PR #1)
| Day | Auto-Start | Auto-Stop |
|-----|-----------|-----------|
| Monday-Friday | 7:00 AM UTC | 8:00 PM UTC |
| Saturday-Sunday | Off | Off |

---

## SSH Access

```bash
# SSH to monitoring server (Instance 1)
ssh -i your-key.pem ubuntu@<MONITORING_IP>

# SSH to app server (Instance 2 or 3)
ssh -i your-key.pem ubuntu@<APP_IP>

# Check services on the instance
docker ps                          # Running containers
docker-compose logs -f             # Live logs
systemctl status node_exporter     # Node exporter status
curl localhost:3000/health         # App health check
curl localhost:3001/api/health     # Grafana health check
```

---

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           AWS Cloud (us-east-1)          │
                    └─────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                                                      │
│                                                                         │
│  ┌─── EC2 Instance 1 (Monitoring Server) ─────────────────────────┐   │
│  │  Role: monitoring                                                │   │
│  │                                                                   │   │
│  │  ┌─────────┐  ┌──────┐  ┌────────────┐  ┌──────────┐          │   │
│  │  │ Grafana │  │ Loki │  │ Prometheus │  │ Promtail │          │   │
│  │  │  :3001  │  │:3100 │  │   :9090    │  │  :9080   │          │   │
│  │  └─────────┘  └──────┘  └────────────┘  └──────────┘          │   │
│  │  ┌──────────────┐  ┌──────────────┐                            │   │
│  │  │  Node.js App │  │ Node Exporter│                            │   │
│  │  │    :3000     │  │    :9100     │                            │   │
│  │  └──────────────┘  └──────────────┘                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─── EC2 Instance 2 (App Server) ────────────────────────────────┐   │
│  │  Role: application                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐                            │   │
│  │  │  Node.js App │  │ Node Exporter│  → metrics → Prometheus    │   │
│  │  │    :3000     │  │    :9100     │  → logs → Loki             │   │
│  │  └──────────────┘  └──────────────┘                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─── EC2 Instance 3 (App Server) ────────────────────────────────┐   │
│  │  Role: application                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐                            │   │
│  │  │  Node.js App │  │ Node Exporter│  → metrics → Prometheus    │   │
│  │  │    :3000     │  │    :9100     │  → logs → Loki             │   │
│  │  └──────────────┘  └──────────────┘                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘

Data Flow:
  App → Winston Logger → Loki → Grafana (Logs)
  App → /metrics endpoint → Prometheus → Grafana (Metrics)
  EC2 → Node Exporter → Prometheus → Grafana (Infra Metrics)
```

---

## Cost Estimation

### All 3 Instances Running 24/7

| Resource | Monthly Cost |
|----------|-------------|
| 3x t3.medium EC2 | ~$90 |
| 3x 30GB gp3 EBS | ~$7.50 |
| 3x Elastic IPs (attached) | Free |
| S3 (state) | ~$0.05 |
| DynamoDB (locks) | ~$0.01 |
| **Total** | **~$98/month** |

### With Auto Stop/Start (12 hrs/day, weekdays only)

| Resource | Monthly Cost |
|----------|-------------|
| 3x t3.medium (12hrs x 22days) | ~$37 |
| 3x 30GB gp3 EBS | ~$7.50 |
| 3x Elastic IPs (detached when stopped) | ~$11 |
| **Total** | **~$56/month** |

### Cost Saving Tips
- Use EC2 Toggle to **stop instances at night**
- Enable the scheduled auto-stop (merge PR #1)
- Consider `t3.small` for non-production ($0.0208/hr vs $0.0416/hr)
- Reduce to 2 instances if 3 aren't needed

---

## Troubleshooting

### Can't access Grafana/App in browser
- Check Security Group allows your IP on ports 3000, 3001
- Check instance is **running** (not stopped)
- Check public IP hasn't changed (use Elastic IP)
- Try: `curl http://<IP>:3000/health` from your machine

### Terraform apply failed
- Check AWS secrets are set in GitHub (Settings → Secrets)
- Check S3 bucket exists: `aws s3 ls | grep ai-monitoring`
- Check key pair exists: `aws ec2 describe-key-pairs --region us-east-1`

### Docker containers not starting
```bash
ssh ubuntu@<IP>
cd /opt/monitoring-app
docker-compose ps          # Check status
docker-compose logs        # Check errors
docker-compose up -d       # Restart all
```

### No data in Grafana dashboards
- Wait 2-3 minutes after starting (Prometheus needs to scrape)
- Generate some traffic: `curl http://<IP>:3000/api/users`
- Check Prometheus targets: `http://<IP>:9090/targets`
- Check Loki: `http://<IP>:3100/ready`

### Pipeline fails
- Check GitHub Actions tab for error details
- Ensure all secrets are added (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_KEY_PAIR_NAME)
- Run with `plan` first before `apply`

---

## Quick Reference Card

```
Grafana:     http://<MONITORING_IP>:3001  (admin/admin123)
Prometheus:  http://<MONITORING_IP>:9090
App:         http://<ANY_IP>:3000
Health:      http://<ANY_IP>:3000/health
Metrics:     http://<ANY_IP>:3000/metrics
SSH:         ssh -i key.pem ubuntu@<IP>

Start EC2:   GitHub Actions → EC2 Toggle → start → all
Stop EC2:    GitHub Actions → EC2 Toggle → stop → all
Deploy:      GitHub Actions → Deploy Infrastructure → apply
Destroy:     GitHub Actions → Deploy Infrastructure → destroy
```
