#!/bin/bash
set -e

echo "🚀 Deploying INFOMATRIX-ASIA 2026 to EC2..."

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Config ──────────────────────────────────────────────
INSTANCE_ID=i-08eb56616ddb569bc
AWS_REGION=eu-north-1
S3_BUCKET=alashed-media
APP_NAME=alashed-infomatrix
APP_DIR=/home/ubuntu/infomatrix
PORT=4000   # different port so it doesn't clash with other apps

# Load AWS creds from .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep 'AWS_' | xargs 2>/dev/null)
fi

# Fallback: hardcoded from project credentials
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-AKIAUWNX2GDY66AB3BLN}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-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}
export AWS_REGION=${AWS_REGION:-eu-north-1}

# ── 1. Package ───────────────────────────────────────────
echo -e "${BLUE}1/4${NC} Creating deployment package..."
tar -czf /tmp/infomatrix-deploy.tar.gz \
  --exclude=node_modules \
  --exclude=.git \
  --exclude='*.tar.gz' \
  --exclude=.env \
  .

# ── 2. Upload to S3 ──────────────────────────────────────
echo -e "${BLUE}2/4${NC} Uploading to S3..."
S3_KEY="deploys/${APP_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz"
aws s3 cp /tmp/infomatrix-deploy.tar.gz "s3://${S3_BUCKET}/${S3_KEY}" \
  --region "$AWS_REGION"

PRESIGNED_URL=$(aws s3 presign "s3://${S3_BUCKET}/${S3_KEY}" \
  --expires-in 600 --region "$AWS_REGION")

# ── 3. Deploy via SSM ────────────────────────────────────
echo -e "${BLUE}3/4${NC} Deploying to EC2 via SSM..."
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --region "$AWS_REGION" \
  --parameters "commands=[
    'echo \"[infomatrix] Starting deploy...\"',
    'sudo -u ubuntu bash -c \"mkdir -p ${APP_DIR}\"',
    'sudo -u ubuntu bash -c \"cd /tmp && curl -s -o infomatrix.tar.gz \\\"${PRESIGNED_URL}\\\"\"',
    'sudo -u ubuntu bash -c \"rm -rf ${APP_DIR}.old && (mv ${APP_DIR} ${APP_DIR}.old 2>/dev/null || true) && mkdir -p ${APP_DIR}\"',
    'sudo -u ubuntu bash -c \"cd /tmp && tar -xzf infomatrix.tar.gz -C ${APP_DIR}\"',
    'sudo -u ubuntu bash -c \"cd ${APP_DIR} && npm install --production\"',
    'sudo bash -c \"cat > /etc/systemd/system/infomatrix.service << EOL\n[Unit]\nDescription=INFOMATRIX Robot Football Judge\nAfter=network.target\n\n[Service]\nUser=ubuntu\nWorkingDirectory=${APP_DIR}\nExecStart=/usr/bin/node server.js\nRestart=always\nEnvironment=PORT=${PORT}\nEnvironment=NODE_ENV=production\n\n[Install]\nWantedBy=multi-user.target\nEOL\"',
    'sudo systemctl daemon-reload',
    'sudo systemctl enable infomatrix',
    'sudo systemctl restart infomatrix',
    'sudo systemctl status infomatrix --no-pager',
    'echo \"[infomatrix] Deploy complete on port ${PORT}\"'
  ]" \
  --output text --query "Command.CommandId")

echo -e "${BLUE}4/4${NC} Waiting for command to finish (ID: $COMMAND_ID)..."
sleep 15

STATUS=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query "Status" --output text 2>/dev/null || echo "Unknown")

echo -e "${GREEN}✓ Deploy status: ${STATUS}${NC}"
echo ""
echo -e "${YELLOW}Access URLs (replace with your EC2 public IP/domain):${NC}"
echo "  Admin:   http://<EC2-IP>:${PORT}/admin"
echo "  Display: http://<EC2-IP>:${PORT}/"
echo ""
echo "To check logs on EC2:"
echo "  ssh ubuntu@<EC2-IP> 'sudo journalctl -u infomatrix -f'"

rm -f /tmp/infomatrix-deploy.tar.gz
echo -e "${GREEN}✓ Done!${NC}"
