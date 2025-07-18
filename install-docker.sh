#!/bin/bash

set -e

echo "[+] Step 1: Removing conflicting curl-minimal (if any)..."
sudo yum remove -y curl-minimal || true
sudo yum install -y curl --allowerasing

echo "[+] Step 2: Installing dependencies..."
sudo yum install -y tar iptables iproute container-selinux conntrack

# Ensure iptables is in standard path
sudo ln -sf /usr/sbin/iptables /usr/bin/iptables

echo "[+] Step 3: Downloading Docker binaries..."
DOCKER_VERSION="24.0.7"
curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz -o docker.tgz
tar xzvf docker.tgz
sudo mv docker/* /usr/bin/
rm -rf docker docker.tgz

echo "[+] Step 4: Installing containerd..."
CONTAINERD_VERSION="1.7.15"
curl -LO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar -xvzf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo mv bin/* /usr/bin/
rm -rf bin containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

echo "[+] Step 5: Configuring containerd service..."
sudo tee /etc/systemd/system/containerd.service > /dev/null <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStart=/usr/bin/containerd
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

echo "[+] Step 6: Configuring Docker service..."
sudo tee /etc/systemd/system/docker.service > /dev/null <<EOF
[Unit]
Description=Docker Service
After=network.target containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=2
StartLimitInterval=0
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
Delegate=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now docker

echo "[+] Step 7: Create docker group and add current user..."
sudo groupadd -f docker
sudo usermod -aG docker $USER
sudo chown root:docker /var/run/docker.sock || true

echo
echo "✅ Docker installed successfully!"
echo "🔁 Run 'newgrp docker' or logout/login for group changes."
echo "🧪 Test with: sudo docker run hello-world"
