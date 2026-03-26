#!/bin/bash
# Fix Nginx SSL configuration for infomatrix.alashed.kz

echo "🔧 Fixing Nginx SSL configuration..."

# Create correct Nginx config
sudo tee /etc/nginx/sites-available/infomatrix > /dev/null << 'EOF'
server {
    listen 80;
    server_name infomatrix.alashed.kz;

    location / {
        proxy_pass         http://127.0.0.1:6666;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/infomatrix /etc/nginx/sites-enabled/infomatrix

# Test and reload
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Nginx config updated for HTTP"
echo ""
echo "Now running certbot to setup SSL..."

# Setup SSL with certbot
sudo certbot --nginx -d infomatrix.alashed.kz \
    --email admin@alashed.kz \
    --agree-tos \
    --non-interactive \
    --redirect

echo ""
echo "✅ SSL setup complete!"
echo "🔍 Testing..."
sleep 2
curl -s https://infomatrix.alashed.kz/health | jq .
