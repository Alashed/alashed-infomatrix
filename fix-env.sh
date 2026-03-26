#!/bin/bash
# Quick fix script to update .env file with RDS connection
# Run this on EC2 instance: bash fix-env.sh

set -e

echo "=== Fixing INFOMATRIX .env for RDS ==="

# Create .env file with RDS configuration
echo "1. Updating .env file..."
sudo -u ubuntu tee /home/ubuntu/infomatrix/.env > /dev/null << 'EOF'
PORT=6666
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix
EOF

echo "2. Restarting infomatrix service..."
sudo systemctl restart infomatrix

echo "3. Waiting for service to start..."
sleep 3

if sudo systemctl is-active --quiet infomatrix; then
    echo "✅ Service is running!"
    echo ""
    echo "Checking database connection..."
    sleep 2
    curl -s http://localhost:6666/health | jq .
else
    echo "❌ Service failed to start!"
    sudo journalctl -u infomatrix -n 50 --no-pager
    exit 1
fi

echo ""
echo "✅ Fix complete!"
echo "🌐 Check: http://infomatrix.alashed.kz/health"
