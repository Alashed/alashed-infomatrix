# 🚀 Быстрое исправление RDS подключения

## Самый простой способ (копировать-вставить в SSH)

```bash
sudo tee /home/ubuntu/infomatrix/.env > /dev/null << 'EOF'
PORT=7000
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix
EOF

sudo chown ubuntu:ubuntu /home/ubuntu/infomatrix/.env
sudo systemctl restart infomatrix
sleep 3 && curl -s http://localhost:7000/health | jq .
```

Должно вернуть:
```json
{
  "status": "ok",
  "db": "connected (XX ms)",
  ...
}
```

## Готово!
После этого проверь:
- ✅ http://infomatrix.alashed.kz/health
- ✅ http://infomatrix.alashed.kz/ (дисплей)
- ✅ http://infomatrix.alashed.kz/admin (админка)

---

Для SSL сертификата:
```bash
sudo certbot --nginx -d infomatrix.alashed.kz --email admin@alashed.kz --agree-tos --non-interactive --redirect
```
