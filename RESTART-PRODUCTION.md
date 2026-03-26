# Перезапуск Production Сервера

## ✅ Команды успешно импортированы в БД!

В PostgreSQL RDS теперь **11 правильных команд** Arduino Hackathon.

## Чтобы production загрузил новые данные:

### Вариант 1: Закрыть все вкладки
1. Закрой все открытые вкладки https://infomatrix.alashed.kz/admin
2. Подожди 5 секунд
3. Открой заново - команды загрузятся из БД

### Вариант 2: SSH на сервер (РЕКОМЕНДУЮ)
```bash
ssh ubuntu@13.62.193.249
sudo systemctl restart infomatrix
sleep 3 && curl -s http://localhost:6666/health | jq .
```

### Вариант 3: Через AWS Console
1. Открой EC2 Console
2. Найди инстанс `i-08eb56616ddb569bc`
3. Session Manager → Connect
4. Выполни:
```bash
sudo systemctl restart infomatrix
```

## Проверка

После перезапуска проверь:
```bash
curl -s https://infomatrix.alashed.kz/state | jq '.teams | length'
```

Должно вернуть: **11**

## Список команд в БД

1. TECHNO MUSCLE (Kazakhstan)
2. DoubleAoneZ (Kazakhstan)
3. Aqtobe BIL (Kazakhstan)
4. Petro BIL (Kazakhstan)
5. L33TechForce (Kazakhstan)
6. MrBig (Kazakhstan)
7. WinLeaders (Kazakhstan)
8. NextGen Tech Girls (Tajikistan)
9. infiNIS (Kazakhstan)
10. TKRobotics (Kazakhstan)
11. NOMAD ROBOTICS (Kazakhstan)

Все с полными данными участников!
