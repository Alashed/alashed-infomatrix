#!/bin/bash
# Restart production infomatrix service
echo "🔄 Перезапуск production сервера..."

# Method 1: Try AWS EC2 Instance Connect (if available)
if command -v aws &> /dev/null; then
    echo "Попытка через EC2 Instance Connect..."
    aws ec2-instance-connect send-ssh-public-key \
        --instance-id i-08eb56616ddb569bc \
        --instance-os-user ubuntu \
        --ssh-public-key file://~/.ssh/id_rsa.pub \
        --availability-zone eu-north-1a \
        --region eu-north-1 2>/dev/null

    if [ $? -eq 0 ]; then
        ssh -o "IdentitiesOnly=yes" ubuntu@13.62.193.249 "sudo systemctl restart infomatrix && sleep 3 && curl -s http://localhost:6666/health | jq ."
        exit 0
    fi
fi

# Method 2: Direct SSH (needs key)
echo ""
echo "Подключись к серверу одним из способов:"
echo ""
echo "1️⃣  SSH (если есть ключ):"
echo "   ssh ubuntu@13.62.193.249"
echo "   sudo systemctl restart infomatrix"
echo ""
echo "2️⃣  AWS Session Manager:"
echo "   aws ssm start-session --target i-08eb56616ddb569bc --region eu-north-1"
echo "   sudo systemctl restart infomatrix"
echo ""
echo "3️⃣  AWS Console → EC2 → Session Manager"
echo ""
echo "После перезапуска проверь:"
echo "   curl https://infomatrix.alashed.kz/state | jq '.teams | length'"
echo "   Должно быть: 11"
