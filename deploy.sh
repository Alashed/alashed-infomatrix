#!/bin/bash
set -e

echo "🚀 Deploying INFOMATRIX-ASIA 2026 → infomatrix.alashed.kz"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Config ─────────────────────────────────────────────────────
INSTANCE_ID=i-08eb56616ddb569bc
AWS_REGION=eu-north-1
S3_BUCKET=alashed-media
APP_NAME=alashed-infomatrix
APP_DIR=/home/ubuntu/infomatrix
PORT=6666
DOMAIN=infomatrix.alashed.kz
EMAIL=admin@alashed.kz

# ── Load .env ──────────────────────────────────────────────────
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep -E '^(AWS_|ADMIN_|DB_)' | xargs 2>/dev/null)
fi
export AWS_REGION=${AWS_REGION:-eu-north-1}
ADMIN_TOKEN=${ADMIN_TOKEN:-infomatrix2026}
DB_NAME=${DB_NAME:-infomatrix}
DB_USER=${DB_USER:-alashed_user}
DB_PASSWORD=${DB_PASSWORD:-alashed01}
# Use RDS instead of localhost
RDS_HOST=${RDS_HOST:-alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com}
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${RDS_HOST}:5432/${DB_NAME}"

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo -e "${RED}❌ AWS credentials missing. Add AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY to .env${NC}"
  exit 1
fi

# ── 1. Package ─────────────────────────────────────────────────
echo -e "${BLUE}1/5${NC} Creating deployment package..."
tar -czf /tmp/infomatrix-deploy.tar.gz \
  --exclude=node_modules \
  --exclude=.git \
  --exclude='*.tar.gz' \
  --exclude=.env \
  --exclude=state.json \
  .

# ── 2. Upload to S3 ────────────────────────────────────────────
echo -e "${BLUE}2/5${NC} Uploading to S3..."
S3_KEY="deploys/${APP_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz"
aws s3 cp /tmp/infomatrix-deploy.tar.gz "s3://${S3_BUCKET}/${S3_KEY}" \
  --region "$AWS_REGION" --no-progress

PRESIGNED_URL=$(aws s3 presign "s3://${S3_BUCKET}/${S3_KEY}" \
  --expires-in 900 --region "$AWS_REGION")

# ── 3. Deploy app via SSM ──────────────────────────────────────
echo -e "${BLUE}3/5${NC} Deploying app to EC2..."
CMD1=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --region "$AWS_REGION" \
  --comment "infomatrix-deploy-app" \
  --parameters "commands=[
    'echo \"=== INFOMATRIX DEPLOY (RDS) ===\"',
    'sudo -u ubuntu mkdir -p ${APP_DIR}',
    'cd /tmp && curl -sf -o infomatrix.tar.gz \"${PRESIGNED_URL}\"',
    'sudo -u ubuntu bash -c \"rm -rf ${APP_DIR}.old; mv ${APP_DIR} ${APP_DIR}.old 2>/dev/null || true; mkdir -p ${APP_DIR}\"',
    'sudo -u ubuntu bash -c \"tar -xzf /tmp/infomatrix.tar.gz -C ${APP_DIR}\"',
    'sudo -u ubuntu bash -c \"cd ${APP_DIR} && npm install --production --silent\"',
    'printf \"PORT=${PORT}\\nNODE_ENV=production\\nADMIN_TOKEN=${ADMIN_TOKEN}\\nDATABASE_URL=${DATABASE_URL}\\n\" | sudo -u ubuntu tee ${APP_DIR}/.env > /dev/null',
    'sudo bash -c \"cat > /etc/systemd/system/infomatrix.service << \\\"SVCEOF\\\"
[Unit]
Description=INFOMATRIX Robot Football Judge
After=network.target

[Service]
User=ubuntu
WorkingDirectory=${APP_DIR}
EnvironmentFile=${APP_DIR}/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=infomatrix

[Install]
WantedBy=multi-user.target
SVCEOF\"',
    'sudo systemctl daemon-reload',
    'sudo systemctl enable infomatrix',
    'sudo systemctl restart infomatrix',
    'sleep 3 && sudo systemctl is-active infomatrix && echo \"[OK] Service running\"'
  ]" \
  --output text --query "Command.CommandId")

echo "   SSM command: $CMD1"
sleep 20

STATUS1=$(aws ssm get-command-invocation \
  --command-id "$CMD1" --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" --query "Status" --output text 2>/dev/null || echo "Unknown")
echo -e "   App deploy: ${GREEN}${STATUS1}${NC}"

# ── 4. Configure Nginx ─────────────────────────────────────────
echo -e "${BLUE}4/5${NC} Configuring Nginx for ${DOMAIN}..."

NGINX_CONF="server {
    listen 80;
    server_name ${DOMAIN};

    # WebSocket + HTTP proxy to Node.js
    location / {
        proxy_pass         http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header   Upgrade \\\$http_upgrade;
        proxy_set_header   Connection \\\"upgrade\\\";
        proxy_set_header   Host \\\$host;
        proxy_set_header   X-Real-IP \\\$remote_addr;
        proxy_set_header   X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \\\$scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}"

CMD2=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --region "$AWS_REGION" \
  --comment "infomatrix-nginx" \
  --parameters "commands=[
    'sudo bash -c \"cat > /etc/nginx/sites-available/infomatrix << \\\"NGXEOF\\\"
${NGINX_CONF}
NGXEOF\"',
    'sudo ln -sf /etc/nginx/sites-available/infomatrix /etc/nginx/sites-enabled/infomatrix',
    'sudo nginx -t && sudo systemctl reload nginx && echo \"[OK] Nginx reloaded\"'
  ]" \
  --output text --query "Command.CommandId")

sleep 12
STATUS2=$(aws ssm get-command-invocation \
  --command-id "$CMD2" --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" --query "Status" --output text 2>/dev/null || echo "Unknown")
echo -e "   Nginx:      ${GREEN}${STATUS2}${NC}"

# ── 5. SSL via Certbot ─────────────────────────────────────────
echo -e "${BLUE}5/5${NC} Issuing SSL certificate for ${DOMAIN}..."
echo -e "   ${YELLOW}⚠ DNS A-record must point to EC2 IP before this step!${NC}"
echo -e "   ${YELLOW}  Check: dig ${DOMAIN} +short${NC}"
echo ""
read -p "   DNS ready? Run certbot now? [y/N]: " SSL_CONFIRM

if [[ "$SSL_CONFIRM" =~ ^[Yy]$ ]]; then
  CMD3=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --region "$AWS_REGION" \
    --comment "infomatrix-certbot" \
    --parameters "commands=[
      'sudo certbot --nginx -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --redirect && echo \"[OK] SSL issued\"'
    ]" \
    --output text --query "Command.CommandId")
  echo "   Certbot SSM: $CMD3 (takes ~30s)"
  sleep 35
  STATUS3=$(aws ssm get-command-invocation \
    --command-id "$CMD3" --instance-id "$INSTANCE_ID" \
    --region "$AWS_REGION" --query "Status" --output text 2>/dev/null || echo "Unknown")
  echo -e "   Certbot:    ${GREEN}${STATUS3}${NC}"
else
  echo -e "   ${YELLOW}Skipped. Run later on the server:${NC}"
  echo "   sudo certbot --nginx -d ${DOMAIN} --email ${EMAIL} --agree-tos --non-interactive --redirect"
fi

# ── Done ───────────────────────────────────────────────────────
rm -f /tmp/infomatrix-deploy.tar.gz

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""
echo -e "  🌐 Display:  https://${DOMAIN}/"
echo -e "  🔐 Admin:    https://${DOMAIN}/admin"
echo -e "     Password: ${ADMIN_TOKEN}"
echo -e "  ❤  Health:   https://${DOMAIN}/health"
echo ""
echo -e "  Logs: aws ssm start-session --target ${INSTANCE_ID} --region ${AWS_REGION}"
echo -e "        then: sudo journalctl -u infomatrix -f"
