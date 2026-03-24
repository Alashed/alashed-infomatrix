#!/bin/bash
# Server-side deployment script for INFOMATRIX
# This script runs on EC2 instance via SSM

set -e

echo "=== INFOMATRIX Server Deploy ==="

# Read parameters from file if exists
if [ -f /tmp/infomatrix-deploy-params.env ]; then
  source /tmp/infomatrix-deploy-params.env
fi

# Defaults
APP_DIR=${APP_DIR:-/home/ubuntu/infomatrix}
PORT=${PORT:-7000}
ADMIN_TOKEN=${ADMIN_TOKEN:-infomatrix2026}
DB_USER=${DB_USER:-infomatrix}
DB_PASSWORD=${DB_PASSWORD:-infomatrix2026}
DB_NAME=${DB_NAME:-infomatrix}
DATABASE_URL=${DATABASE_URL:-postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}}

# 1. Download from S3
if [ -n "$PRESIGNED_URL" ]; then
  echo "1. Downloading from S3..."
  cd /tmp && curl -sf -o infomatrix.tar.gz "$PRESIGNED_URL"
else
  echo "Error: PRESIGNED_URL not set"
  exit 1
fi

# 2. Backup and extract
echo "2. Extracting new version..."
sudo -u ubuntu bash -c "rm -rf ${APP_DIR}.old"
sudo -u ubuntu bash -c "mv ${APP_DIR} ${APP_DIR}.old 2>/dev/null || true"
sudo -u ubuntu bash -c "mkdir -p ${APP_DIR}"
sudo -u ubuntu bash -c "tar -xzf /tmp/infomatrix.tar.gz -C ${APP_DIR}"

# 3. Install dependencies
echo "3. Installing dependencies..."
sudo -u ubuntu bash -c "cd ${APP_DIR} && npm install --production --silent"

# 4. Create .env file
echo "4. Creating .env file..."
sudo -u ubuntu bash -c "cat > ${APP_DIR}/.env << EOF
PORT=${PORT}
NODE_ENV=production
ADMIN_TOKEN=${ADMIN_TOKEN}
DATABASE_URL=${DATABASE_URL}
EOF"

# 5. Restart via PM2
echo "5. Restarting application..."
sudo -u ubuntu pm2 delete infomatrix 2>/dev/null || true
sudo -u ubuntu bash -c "cd ${APP_DIR} && PORT=${PORT} NODE_ENV=production ADMIN_TOKEN=${ADMIN_TOKEN} DATABASE_URL='${DATABASE_URL}' pm2 start ecosystem.config.js"
sleep 3
sudo -u ubuntu pm2 save

# 6. Health check
echo "6. Checking health..."
sleep 2
curl -sf http://localhost:${PORT}/health | jq . || echo "Health check failed"

echo ""
echo "✅ Deployment complete!"
