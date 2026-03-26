# 🚨 СРОЧНЫЙ ПЕРЕЗАПУСК Production

## Проблема
Production сервер упал (502 Bad Gateway)

## ✅ Данные в безопасности!
Все 11 команд уже в БД PostgreSQL, просто нужно перезапустить сервис.

## Как перезапустить (выбери любой способ):

### 🔥 Способ 1: AWS Console (самый простой)

1. Открой https://eu-north-1.console.aws.amazon.com/ec2/home?region=eu-north-1#Instances:
2. Найди инстанс `i-08eb56616ddb569bc`
3. Нажми **Connect** → **Session Manager** → **Connect**
4. В терминале выполни:
   ```bash
   sudo systemctl restart infomatrix
   sleep 3
   curl -s http://localhost:6666/health | jq .
   ```

### 🔥 Способ 2: Терминал (если есть AWS CLI)

```bash
aws ssm start-session --target i-08eb56616ddb569bc --region eu-north-1
```

Потом в сессии:
```bash
sudo systemctl restart infomatrix
```

### 🔥 Способ 3: SSH (если есть ключ)

```bash
ssh ubuntu@13.62.193.249
sudo systemctl restart infomatrix
```

### 🔥 Способ 4: Однострочник с сервера

Если можешь подключиться к серверу любым способом, просто выполни:
```bash
sudo systemctl restart infomatrix && sleep 3 && curl -s http://localhost:6666/health | jq .
```

## После перезапуска:

Проверь что всё работает:
```bash
curl -s https://infomatrix.alashed.kz/health | jq .
```

Должно вернуть:
```json
{
  "status": "ok",
  "db": "connected (2ms)",
  "clients": 0,
  "hasState": true,
  "uptime": <секунды>
}
```

И проверь команды:
```bash
curl -s https://infomatrix.alashed.kz/state | jq '.teams | length'
```

Должно вернуть: **11**

## Если упал снова

Посмотри логи:
```bash
sudo journalctl -u infomatrix -n 100 --no-pager
```

Или перезапусти с выводом логов:
```bash
sudo systemctl restart infomatrix
sudo journalctl -u infomatrix -f
```
