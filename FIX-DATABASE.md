# Исправление подключения к RDS базе данных

## Проблема
Сервер на production не может подключиться к RDS базе данных из-за неправильного .env файла.

## Решение

### Вариант 1: Быстрое исправление (только .env)
Запустить на EC2 сервере:
```bash
curl -sf https://alashed-media.s3.eu-north-1.amazonaws.com/scripts/fix-infomatrix-env.sh | bash
```

Или скачать и запустить:
```bash
wget -q https://alashed-media.s3.eu-north-1.amazonaws.com/scripts/fix-infomatrix-env.sh -O fix-env.sh
chmod +x fix-env.sh
./fix-env.sh
```

### Вариант 2: Полный редеплой
Запустить на EC2 сервере:
```bash
cd /tmp
wget -q https://raw.githubusercontent.com/alashed/infomatrix/main/manual-deploy.sh
chmod +x manual-deploy.sh
sudo ./manual-deploy.sh
```

### Вариант 3: Через SSH
```bash
ssh ubuntu@<EC2-IP>
sudo su -
cat > /home/ubuntu/infomatrix/.env << 'EOF'
PORT=7000
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix
EOF

chown ubuntu:ubuntu /home/ubuntu/infomatrix/.env
systemctl restart infomatrix
systemctl status infomatrix
```

## Проверка
После исправления проверить здоровье:
```bash
curl http://localhost:7000/health | jq .
```

Должно вернуть:
```json
{
  "status": "ok",
  "db": "connected (XX ms)",
  "clients": 0,
  "hasState": true,
  "uptime": XXX
}
```

## Диагностика

### Проверить текущий .env
```bash
cat /home/ubuntu/infomatrix/.env
```

### Проверить логи сервиса
```bash
sudo journalctl -u infomatrix -n 100 --no-pager
```

### Проверить подключение к RDS с сервера
```bash
psql "postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix" -c "SELECT 1"
```

## Детали RDS
- **Host**: alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com
- **Port**: 5432
- **Database**: infomatrix
- **User**: alashed_user
- **Password**: alashed01
- **SSL**: Required (rejectUnauthorized: false)

## Security Groups
- RDS SG: `sg-0bd36d873f6a77e32` - разрешает подключения от EC2 SG
- EC2 SG: `sg-041b6f31dc0619dfb` - имеет доступ к RDS

## Что было исправлено
1. ✅ Код на сервере обновлен (есть функции `computeStateHash`, `stateHash`)
2. ✅ База данных RDS работает и имеет правильные таблицы
3. ✅ Security groups настроены корректно
4. ❌ .env файл на сервере НЕ обновлен (нужно исправить вручную)

## SSL Certificate
⚠️ Также нужно настроить SSL сертификат для infomatrix.alashed.kz:
```bash
sudo certbot --nginx -d infomatrix.alashed.kz --email admin@alashed.kz --agree-tos --non-interactive --redirect
```
