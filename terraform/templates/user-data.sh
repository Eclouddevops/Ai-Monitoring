#!/bin/bash
set -euo pipefail

# Log all output
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting instance setup (Instance ${instance_index}, Role: ${instance_role}) ==="

# Update system
apt-get update -y
apt-get upgrade -y

# Install essential packages
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  unzip \
  jq \
  htop

# ==========================================
# Install Docker
# ==========================================
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# ==========================================
# Install Docker Compose
# ==========================================
echo "=== Installing Docker Compose ==="
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# ==========================================
# Install Node.js 18
# ==========================================
echo "=== Installing Node.js 18 ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# ==========================================
# Install AWS CLI v2
# ==========================================
echo "=== Installing AWS CLI v2 ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ==========================================
# Install Node Exporter
# ==========================================
echo "=== Installing Node Exporter ==="
NODE_EXPORTER_VERSION="1.7.0"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -O /tmp/node_exporter.tar.gz
tar xzf /tmp/node_exporter.tar.gz -C /tmp
mv /tmp/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf /tmp/node_exporter*

# Create node_exporter systemd service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# ==========================================
# Setup Application Directory
# ==========================================
echo "=== Setting up application directory ==="
mkdir -p /opt/monitoring-app
chown ubuntu:ubuntu /opt/monitoring-app

# ==========================================
# Set Environment Variables
# ==========================================
echo "=== Setting environment variables ==="
cat > /opt/monitoring-app/.env <<EOF
INSTANCE_ID=instance-${instance_index}
INSTANCE_ROLE=${instance_role}
ENVIRONMENT=${environment}
LOKI_HOST=${loki_url}
NODE_ENV=${environment}
PORT=3000
EOF

# Add environment variables to ubuntu user profile
cat >> /home/ubuntu/.bashrc <<EOF

# Monitoring Stack Environment
export INSTANCE_ID=instance-${instance_index}
export INSTANCE_ROLE=${instance_role}
export ENVIRONMENT=${environment}
export LOKI_HOST=${loki_url}
EOF

# ==========================================
# Create Monitoring App Systemd Service
# ==========================================
echo "=== Creating monitoring app service ==="
cat > /etc/systemd/system/monitoring-app.service <<EOF
[Unit]
Description=Monitoring Application Stack
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/monitoring-app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu
Group=docker

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable monitoring-app

echo "=== Instance setup complete (Instance ${instance_index}, Role: ${instance_role}) ==="
