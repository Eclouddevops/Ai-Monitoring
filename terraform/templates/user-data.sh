#!/bin/bash
set -eo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "==========================================="
echo "  AI-MONITORING: Full Stack Auto Setup"
echo "  Time: $(date)"
echo "==========================================="

# ==========================================
# 1. System Update & Packages
# ==========================================
echo "[1/8] Installing system packages..."
apt-get update -y
apt-get install -y \
  apt-transport-https ca-certificates curl gnupg \
  lsb-release unzip jq htop git

# ==========================================
# 2. Install Docker
# ==========================================
echo "[2/8] Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# ==========================================
# 3. Install Docker Compose
# ==========================================
echo "[3/8] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ==========================================
# 4. Install SSM Agent
# ==========================================
echo "[4/8] Installing SSM Agent..."
snap install amazon-ssm-agent --classic 2>/dev/null || true
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true

# ==========================================
# 5. Clone Repository
# ==========================================
echo "[5/8] Cloning application repository..."
git clone https://github.com/Eclouddevops/Ai-Monitoring.git /opt/app-repo

# ==========================================
# 6. Setup Application
# ==========================================
echo "[6/8] Setting up application..."
mkdir -p /opt/monitoring-app
cp -r /opt/app-repo/monitoring/* /opt/monitoring-app/
cp -r /opt/app-repo/nodejs-app /opt/monitoring-app/nodejs-app

# Create .env file
cat > /opt/monitoring-app/.env << EOF
INSTANCE_ID=ai-monitoring-server
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
LOKI_HOST=http://loki:3100
NODE_ENV=${environment}
PORT=3000
EOF

chown -R ubuntu:ubuntu /opt/monitoring-app

# ==========================================
# 7. Build & Start All Services
# ==========================================
echo "[7/8] Building and starting all services..."
cd /opt/monitoring-app

# Build Node.js app
docker build -t nodejs-loki-app:latest /opt/monitoring-app/nodejs-app/

# Start everything
docker-compose up -d

# ==========================================
# 8. Create Auto-Start Service (survives reboot)
# ==========================================
echo "[8/8] Configuring auto-start on reboot..."
cat > /etc/systemd/system/monitoring-stack.service << 'EOF'
[Unit]
Description=AI Monitoring Stack (Docker Compose)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/monitoring-app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable monitoring-stack

# ==========================================
# Wait & Verify
# ==========================================
echo ""
echo "Waiting 20 seconds for all services to start..."
sleep 20

echo ""
echo "==========================================="
echo "  HEALTH CHECK"
echo "==========================================="

check() {
    local name="$1" url="$2"
    local code
    code=$(curl -s -o /dev/null -w "%%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
        echo "  [OK]   $name (HTTP $code)"
    else
        echo "  [FAIL] $name (HTTP $code)"
    fi
}

check "Node.js App"  "http://localhost:3000/health"
check "Grafana"      "http://localhost:3001/api/health"
check "Prometheus"   "http://localhost:9090/-/healthy"
check "Loki"         "http://localhost:3100/ready"

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")

echo ""
echo "==========================================="
echo "  SETUP COMPLETE!"
echo "==========================================="
echo ""
echo "  Access your services:"
echo "  ────────────────────────────────────────"
echo "  Grafana:     http://$PUBLIC_IP:3001"
echo "  Login:       admin / admin123"
echo ""
echo "  Node.js App: http://$PUBLIC_IP:3000"
echo "  Prometheus:  http://$PUBLIC_IP:9090"
echo "  Loki:        http://$PUBLIC_IP:3100"
echo ""
echo "  Docker auto-starts on reboot: YES"
echo "==========================================="
