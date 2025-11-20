#!/bin/bash
# Setup PM2, NATS, and Go on Ubuntu server for ARC

set -e

echo "=== Installing Build Tools ==="
# Install GCC and build essentials for CGO
apt-get update
apt-get install -y build-essential

echo "=== Installing Go ==="
# Install Go 1.23.1 if not already installed
if ! command -v go &> /dev/null; then
    cd /tmp
    wget https://go.dev/dl/go1.23.1.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.23.1.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

echo "=== Installing PM2 ==="
# Install Node.js if not already installed
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    apt-get install -y nodejs
fi

# Install PM2 globally
npm install -g pm2

echo "=== Installing NATS Server ==="
# Download and install NATS server
cd /tmp
wget https://github.com/nats-io/nats-server/releases/download/v2.10.7/nats-server-v2.10.7-linux-amd64.tar.gz
tar -xzf nats-server-v2.10.7-linux-amd64.tar.gz
cp nats-server-v2.10.7-linux-amd64/nats-server /usr/local/bin/
chmod +x /usr/local/bin/nats-server

# Create NATS systemd service
cat > /etc/systemd/system/nats.service << 'EOF'
[Unit]
Description=NATS Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nats-server -js -p 4222 -m 8222
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# Start NATS
systemctl daemon-reload
systemctl enable nats
systemctl start nats

echo "=== Creating logs directory ==="
mkdir -p /root/arc-observe/logs

echo "=== Building ARC binary ==="
cd /root/arc-observe
export PATH=$PATH:/usr/local/go/bin
export CGO_ENABLED=1
echo "Building with CGO enabled..."
go build -o arc ./cmd/arc/main.go
chmod +x arc
echo "ARC binary built successfully: $(ls -lh arc | awk '{print $5}')"

echo "=== Setting up PM2 startup ==="
# Configure PM2 to start on boot
pm2 startup systemd -u root --hp /root
# This will output a command - run it manually or it will be in the script output

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Start services: pm2 start ecosystem.config.js"
echo "2. Save PM2 configuration: pm2 save"
echo "3. Check status: pm2 status"
echo "4. View logs: pm2 logs"
