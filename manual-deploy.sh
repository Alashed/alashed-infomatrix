#!/bin/bash
# Manual deployment script for INFOMATRIX
# Run this directly on EC2 instance

set -e

echo "=== INFOMATRIX Manual Deploy ==="

# Download from S3
echo "1. Downloading latest build from S3..."
cd /tmp
wget -q "https://alashed-media.s3.eu-north-1.amazonaws.com/deploys/alashed-infomatrix-20260324-054329.tar.gz" -O infomatrix.tar.gz

# Backup old version
echo "2. Backing up old version..."
sudo rm -rf /home/ubuntu/infomatrix.old 2>/dev/null || true
sudo mv /home/ubuntu/infomatrix /home/ubuntu/infomatrix.old 2>/dev/null || true

# Extract new version
echo "3. Extracting new version..."
sudo mkdir -p /home/ubuntu/infomatrix
sudo tar -xzf /tmp/infomatrix.tar.gz -C /home/ubuntu/infomatrix
sudo chown -R ubuntu:ubuntu /home/ubuntu/infomatrix

# Install dependencies
echo "4. Installing dependencies..."
cd /home/ubuntu/infomatrix
sudo -u ubuntu npm install --production --silent

# Create .env file
echo "5. Creating .env configuration..."
sudo -u ubuntu tee /home/ubuntu/infomatrix/.env > /dev/null << 'EOF'
PORT=7000
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://infomatrix:infomatrix2026@localhost:5432/infomatrix
EOF

# Restart service
echo "6. Restarting infomatrix service..."
sudo systemctl restart infomatrix

# Wait and check status
sleep 3
if sudo systemctl is-active --quiet infomatrix; then
    echo "✅ Service is running!"
    sudo systemctl status infomatrix --no-pager
else
    echo "❌ Service failed to start!"
    sudo journalctl -u infomatrix -n 50 --no-pager
    exit 1
fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 Check: https://infomatrix.alashed.kz/health"
