# Workflow Guide — Ai-Monitoring

Complete step-by-step guide for all GitHub Actions workflows.

---

## Table of Contents

1. [All Workflows Overview](#all-workflows-overview)
2. [Prerequisites](#prerequisites)
3. [First-Time Deployment](#first-time-deployment)
4. [Daily Usage - Start & Stop EC2](#daily-usage---start--stop-ec2)
5. [Snapshot & Backup](#snapshot--backup)
6. [Destroy & Restore from Snapshot](#destroy--restore-from-snapshot)
7. [EC2 Connect & Debug (SSM)](#ec2-connect--debug-ssm)
8. [Accessing Services in Browser](#accessing-services-in-browser)
9. [Using Grafana](#using-grafana)
10. [Using Prometheus](#using-prometheus)
11. [Viewing Logs in Loki](#viewing-logs-in-loki)
12. [Troubleshooting](#troubleshooting)
13. [Cost Management](#cost-management)

---

## All Workflows Overview

| # | Workflow Name | Purpose | When to Use |
|---|-------------|---------|-------------|
| 1 | **Deploy Infrastructure** | Create/destroy EC2 + restore from snapshot | First time & infrastructure changes |
| 2 | **EC2 Start / Stop** | Turn instance ON/OFF | Daily (save cost) |
| 3 | **EC2 Snapshot & Restore** | Backup & restore data | Before changes / weekly |
| 4 | **EC2 Connect & Debug** | Run commands on EC2 remotely | Debugging / checking status |

---

## Prerequisites

### Step 1: Add GitHub Secrets

Go to: https://github.com/Eclouddevops/Ai-Monitoring/settings/secrets/actions

Click **"New repository secret"** and add:

| Secret Name | Value | How to get it |
|-------------|-------|---------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | `cat ~/.aws/credentials` |
| `AWS_SECRET_ACCESS_KEY` | Your secret key | `cat ~/.aws/credentials` |
| `AWS_KEY_PAIR_NAME` | e.g. `my-ec2-key` | `aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text --region us-east-1` |

### Step 2: Merge All Open PRs

Go to https://github.com/Eclouddevops/Ai-Monitoring/pulls and merge any open PRs.

### Step 3: Verify S3 Bucket Exists

```bash
aws s3 ls | grep ai-monitoring-tfstate
```

If not found:
```bash
aws s3api create-bucket --bucket ai-monitoring-tfstate-496251222247 --region us-east-1
```

---

## First-Time Deployment

### Step 1: Go to GitHub Actions

```
https://github.com/Eclouddevops/Ai-Monitoring/actions
```

### Step 2: Run "Deploy Infrastructure"

1. Click **"Deploy Infrastructure"** in the left sidebar
2. Click **"Run workflow"** (blue button, top right)
3. Fill in:
   - **Branch**: `main`
   - **Action**: `apply`
   - **confirm_destroy**: leave empty (not needed for apply)
4. Click **"Run workflow"**

### Step 3: Wait for completion

The pipeline runs these steps:
```
Validate (lint + test) → Build Docker Image → Terraform Plan → Terraform Apply
```
Total time: ~5-8 minutes

### Step 4: Wait 5 more minutes for EC2 setup

After terraform creates the EC2, the instance automatically:
1. Installs Docker & Docker Compose
2. Clones the Ai-Monitoring repo
3. Builds the Node.js Docker image
4. Starts ALL containers (Grafana, Loki, Prometheus, App)
5. Enables auto-start on reboot

### Step 5: Get the IP address

Check the workflow output (Terraform outputs section) for:
```
public_ip = "xx.xx.xx.xx"
grafana_url = "http://xx.xx.xx.xx:3001"
```

### Step 6: Access in browser

| Service | URL | Login |
|---------|-----|-------|
| Grafana | `http://<IP>:3001` | admin / admin123 |
| Node.js App | `http://<IP>:3000` | — |
| Prometheus | `http://<IP>:9090` | — |

---

## Daily Usage - Start & Stop EC2

### Start the Instance (Morning)

1. Go to **Actions** → **EC2 Start / Stop**
2. Click **"Run workflow"**
3. Select: **`START`**
4. Click **"Run workflow"**
5. Wait 2-3 minutes
6. All services auto-start with Docker!

### Stop the Instance (Evening - save cost)

1. Go to **Actions** → **EC2 Start / Stop**
2. Click **"Run workflow"**
3. Select: **`STOP`**
4. Click **"Run workflow"**
5. Instance stops → compute charges paused

### Check Status

1. Go to **Actions** → **EC2 Start / Stop**
2. Click **"Run workflow"**
3. Select: **`STATUS`**
4. Click **"Run workflow"**
5. View output in workflow logs → shows instance state & IP

### Automatic Schedule

| Day | Auto-START | Auto-STOP |
|-----|-----------|-----------|
| Monday-Friday | 7:00 AM UTC | 8:00 PM UTC |
| Saturday-Sunday | — | — (stays off) |

---

## Snapshot & Backup

### Create a Snapshot (Backup)

1. Go to **Actions** → **EC2 Snapshot & Restore**
2. Click **"Run workflow"**
3. Select: **`Create Snapshot`**
4. Click **"Run workflow"**
5. Wait 2-5 minutes for snapshot to complete

**When to take snapshots:**
- Before making changes
- Before destroy
- Weekly backup (or auto daily at 2 AM UTC)

### List All Snapshots

1. Go to **Actions** → **EC2 Snapshot & Restore**
2. Click **"Run workflow"**
3. Select: **`List Snapshots`**
4. Click **"Run workflow"**
5. View output → shows all snapshots with dates

### Restore from Snapshot (replace current volume)

1. Go to **Actions** → **EC2 Snapshot & Restore**
2. Click **"Run workflow"**
3. Select: **`Restore from Latest Snapshot`**
4. Type **`yes`** in the confirm field
5. Click **"Run workflow"**

**What happens:**
```
Instance stops → Old volume detached → New volume from snapshot → Attached → Instance starts
```

### Delete Old Snapshots (keep last 3)

1. Go to **Actions** → **EC2 Snapshot & Restore**
2. Click **"Run workflow"**
3. Select: **`Delete Old Snapshots (keep last 3)`**
4. Type **`yes`** in the confirm field
5. Click **"Run workflow"**

---

## Destroy & Restore from Snapshot

### Destroy Infrastructure (with safety backup)

1. Go to **Actions** → **Deploy Infrastructure**
2. Click **"Run workflow"**
3. Select: **`destroy`**
4. Type **`yes`** in confirm_destroy field
5. Click **"Run workflow"**

**Safety:** A snapshot is automatically created before destroying!

### Recreate from Snapshot (restore all data)

1. Go to **Actions** → **Deploy Infrastructure**
2. Click **"Run workflow"**
3. Select: **`apply-from-snapshot`**
4. Type **`yes`** in confirm_destroy field
5. Click **"Run workflow"**

**What happens:**
```
Finds latest snapshot → Creates AMI → Deploys EC2 with your old data → All configs/dashboards restored!
```

### Complete Destroy & Restore Flow

```
Step 1: Create Snapshot (backup)
   Actions → EC2 Snapshot & Restore → Create Snapshot

Step 2: Destroy Infrastructure
   Actions → Deploy Infrastructure → destroy → type 'yes'
   (Auto-creates another snapshot before destroying!)

Step 3: Recreate with your data
   Actions → Deploy Infrastructure → apply-from-snapshot → type 'yes'
   (Uses latest snapshot → all your Grafana dashboards, configs, logs restored!)

Step 4: Wait 5 minutes → Access Grafana at new IP
```

---

## EC2 Connect & Debug (SSM)

Run commands on your EC2 without SSH keys.

### Run a Command

1. Go to **Actions** → **EC2 Connect & Debug**
2. Click **"Run workflow"**
3. Select instance: **`instance-1 (monitoring)`**
4. Type your command in the command field
5. Click **"Run workflow"**
6. View output in the workflow logs

### Useful Commands

| Command | Purpose |
|---------|---------|
| `docker ps` | Check running containers |
| `docker-compose logs --tail 50` | View recent logs |
| `curl localhost:3000/health` | Check Node.js app |
| `curl localhost:3001/api/health` | Check Grafana |
| `curl localhost:9090/-/healthy` | Check Prometheus |
| `cat /var/log/user-data.log \| tail -30` | Check boot script |
| `df -h` | Check disk space |
| `free -m` | Check memory |
| `docker stats --no-stream` | Container resource usage |

### Connect from Local Machine (interactive)

```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text --region us-east-1)

# Connect (interactive terminal - no SSH key needed!)
aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

---

## Accessing Services in Browser

### Get Your Instance IP

**Option A:** Check workflow output after START or apply

**Option B:** Run from local machine:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=grafana-loki-monitoring" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text --region us-east-1
```

### Open in Browser

| Service | URL | What you see |
|---------|-----|-------------|
| **Grafana** | `http://<IP>:3001` | Login page → Dashboards |
| **Node.js App** | `http://<IP>:3000` | JSON response with app info |
| **App Health** | `http://<IP>:3000/health` | Health status + uptime |
| **Prometheus** | `http://<IP>:9090` | Query interface |
| **Loki** | `http://<IP>:3100/ready` | "ready" text (API only) |
| **Metrics** | `http://<IP>:3000/metrics` | Prometheus metrics text |

---

## Using Grafana

### Login

1. Open: `http://<IP>:3001`
2. Username: **admin**
3. Password: **admin123**
4. Click **"Log in"**

### View Dashboards

1. Click **Dashboards** (4 squares icon in left sidebar)
2. Two pre-built dashboards:
   - **Node.js Application Dashboard** — HTTP requests, latency, app logs
   - **EC2 Infrastructure Dashboard** — CPU, memory, disk, network

### Explore Logs (Loki)

1. Click **Explore** (compass icon in left sidebar)
2. Select **"Loki"** from the top dropdown
3. Type a query:
   - `{app="nodejs-app"}` — All app logs
   - `{app="nodejs-app"} |= "error"` — Error logs only
   - `{job="syslog"}` — System logs
4. Click **"Run query"**

### Explore Metrics (Prometheus)

1. Click **Explore** (compass icon)
2. Select **"Prometheus"** from the top dropdown
3. Type a query:
   - `up` — Which targets are healthy
   - `rate(http_requests_total[5m])` — Request rate
   - `process_resident_memory_bytes / 1024 / 1024` — Memory in MB
4. Click **"Run query"**

### Generate Data (hit these URLs to create dashboard activity)

```bash
# From your local machine - replace <IP> with your EC2 IP:
for i in $(seq 1 50); do
  curl -s http://<IP>:3000/api/users > /dev/null
  curl -s http://<IP>:3000/health > /dev/null
  curl -s -X POST http://<IP>:3000/api/orders -H "Content-Type: application/json" -d '{"items":["test"]}' > /dev/null
done
echo "Done! Check Grafana dashboards now."
```

---

## Using Prometheus

### Access

Open: `http://<IP>:9090`

### Check Targets

1. Click **Status** → **Targets**
2. You should see:
   - `prometheus (1/1 up)` ✅
   - `nodejs-app (1/1 up)` ✅
   - `node-exporter (1/1 up)` ✅

### Run Queries

Type in the query box and click **Execute**:

| Query | Shows |
|-------|-------|
| `up` | Which targets are healthy (1=up, 0=down) |
| `rate(http_requests_total[5m])` | Requests per second |
| `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | p95 latency |
| `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | CPU usage % |
| `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | Memory usage % |

---

## Viewing Logs in Loki

Loki has no UI of its own — view logs through **Grafana → Explore → Loki**.

### Quick Queries

| Query | Description |
|-------|-------------|
| `{app="nodejs-app"}` | All application logs |
| `{app="nodejs-app"} \|= "error"` | Only errors |
| `{app="nodejs-app"} \|= "Order created"` | Order logs |
| `{app="nodejs-app"} \| json \| statusCode="500"` | 500 errors |
| `{job="syslog"}` | System logs |
| `{job="docker"}` | Docker container logs |

### Log Labels

- `app` — Application name
- `environment` — dev/production
- `instance` — Instance ID
- `job` — Log source type

---

## Troubleshooting

### "Connection refused" in browser

| Check | Fix |
|-------|-----|
| Instance running? | Actions → EC2 Start / Stop → STATUS |
| Containers running? | EC2 Connect → `docker ps` |
| Security group? | Open ports 3000,3001,9090 in AWS Console → Security Groups |
| Wait after start | Docker takes 1-2 min to auto-start after EC2 boot |

### "Error acquiring state lock"

Run from local machine:
```bash
aws dynamodb delete-item --table-name ai-monitoring-tf-locks \
  --key '{"LockID":{"S":"ai-monitoring-tfstate-496251222247/terraform.tfstate"}}' \
  --region us-east-1
```

### No data in Grafana dashboards

1. Generate traffic: `curl http://<IP>:3000/api/users` (repeat 10+ times)
2. Wait 2-3 minutes (Prometheus scrapes every 15 seconds)
3. Check Prometheus targets: `http://<IP>:9090/targets`

### Containers not starting after EC2 reboot

SSH/SSM into instance and run:
```bash
cd /opt/monitoring-app && docker-compose up -d
```

If needed, enable auto-start:
```bash
systemctl enable monitoring-stack
```

---

## Cost Management

### Running 24/7 (single t3.medium)

| Resource | Monthly Cost |
|----------|-------------|
| 1x t3.medium EC2 | ~$30 |
| 30GB gp3 EBS | ~$2.50 |
| Elastic IP (attached) | Free |
| Snapshots (~3 x 30GB) | ~$4.50 |
| S3 + DynamoDB | ~$0.10 |
| **Total** | **~$37/month** |

### With daily Start/Stop (12 hrs/day, weekdays)

| Resource | Monthly Cost |
|----------|-------------|
| EC2 (12hrs x 22 days) | ~$12 |
| EBS + Snapshots | ~$7 |
| EIP (detached hours) | ~$4 |
| **Total** | **~$23/month** |

### Fully stopped (only storage)

| Resource | Monthly Cost |
|----------|-------------|
| EBS volume | ~$2.50 |
| Snapshots | ~$4.50 |
| **Total** | **~$7/month** |

### Tips

- Always STOP when not using → saves $1.50/day
- Use auto-schedule (7AM start, 8PM stop)
- Delete old snapshots monthly (keep last 3)
- Destroy completely when not needed for weeks → $0

---

## Quick Reference

| I want to... | Workflow | Action |
|--------------|----------|--------|
| Create infrastructure | Deploy Infrastructure | `apply` |
| Start server | EC2 Start / Stop | `START` |
| Stop server | EC2 Start / Stop | `STOP` |
| Check if running | EC2 Start / Stop | `STATUS` |
| Take a backup | EC2 Snapshot & Restore | `Create Snapshot` |
| See all backups | EC2 Snapshot & Restore | `List Snapshots` |
| Restore from backup | EC2 Snapshot & Restore | `Restore from Latest Snapshot` + 'yes' |
| Delete & recreate | Deploy Infrastructure | `destroy` → `apply-from-snapshot` |
| Run command on EC2 | EC2 Connect & Debug | Select instance + command |
| Delete everything | Deploy Infrastructure | `destroy` + 'yes' |
| View dashboards | Browser | `http://<IP>:3001` |
| View app | Browser | `http://<IP>:3000` |
| View metrics | Browser | `http://<IP>:9090` |
