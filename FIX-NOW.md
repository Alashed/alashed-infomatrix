# 🚨 ИСПРАВИТЬ СЕЙЧАС (1 минута)

## ✅ Данные в безопасности!
Все 11 команд сохранены в PostgreSQL RDS.

## 🔧 Что делать (выбери один способ):

### 🔥 Способ 1: Автоматический скрипт (РЕКОМЕНДУЮ)

Зайди на сервер любым способом и выполни **ОДНУ** команду:

```bash
curl -sf "https://alashed-media.s3.eu-north-1.amazonaws.com/scripts/manual-deploy-latest.sh?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAUWNX2GDYTOOHBOU7%2F20260326%2Feu-north-1%2Fs3%2Faws4_request&X-Amz-Date=20260326T075823Z&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&X-Amz-Signature=7b386cfaff60e6a36883843b9b0b03fc612eee4a593f708a812334600ba8a452" | sudo bash
```

Или короткая версия:
```bash
curl -sf https://alashed-media.s3.eu-north-1.amazonaws.com/deploys/alashed-infomatrix-20260326-125709.tar.gz -o /tmp/infomatrix.tar.gz && \
sudo rm -rf /home/ubuntu/infomatrix.old && \
sudo mv /home/ubuntu/infomatrix /home/ubuntu/infomatrix.old 2>/dev/null || true && \
sudo mkdir -p /home/ubuntu/infomatrix && \
sudo tar -xzf /tmp/infomatrix.tar.gz -C /home/ubuntu/infomatrix && \
sudo chown -R ubuntu:ubuntu /home/ubuntu/infomatrix && \
cd /home/ubuntu/infomatrix && sudo -u ubuntu npm install --production --silent && \
sudo -u ubuntu tee /home/ubuntu/infomatrix/.env > /dev/null << 'EOF'
PORT=6666
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix
EOF
sudo systemctl restart infomatrix && sleep 3 && curl -s http://localhost:6666/health | jq .
```

### 🔥 Способ 2: Вручную (3 команды)

```bash
# 1. Исправь .env
sudo tee /home/ubuntu/infomatrix/.env > /dev/null << 'EOF'
PORT=6666
NODE_ENV=production
ADMIN_TOKEN=infomatrix2026
DATABASE_URL=postgresql://alashed_user:alashed01@alashed-db.cde42ec8m1u7.eu-north-1.rds.amazonaws.com:5432/infomatrix
EOF

# 2. Перезапусти сервис
sudo systemctl restart infomatrix

# 3. Проверь
curl -s http://localhost:6666/health | jq .
```

## 📱 Как подключиться к серверу:

**Вариант A: AWS Console**
1. https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#Instances:
2. Найди `i-08eb56616ddb569bc`
3. Connect → Session Manager → Connect

**Вариант B: Терминал**
```bash
aws ssm start-session --target i-08eb56616ddb569bc --region eu-north-1
```

**Вариант C: SSH**
```bash
ssh ubuntu@13.62.193.249
```

## ✅ Проверка

После исправления:
```bash
curl -s https://infomatrix.alashed.kz/health | jq .
```

Должно вернуть:
```json
{
  "status": "ok",
  "db": "connected (2ms)",
  ...
}
```

И команды:
```bash
curl -s https://infomatrix.alashed.kz/state | jq '.teams | length'
```

Должно быть: **11**

## 📝 Что было:
- Данные импортированы в БД
- Production сервер упал при закрытии админки
- Перезагрузка инстанса не помогла
- Нужно вручную перезапустить сервис
