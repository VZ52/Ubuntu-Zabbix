# Ubuntu-Zabbix

Стенд мониторинга на базе **Zabbix 7** с алертингом в Telegram, разворачивается одной командой через Docker Compose.

Pet-версия мониторинга, который я разворачивал на работе.

## Стек

- **Docker** + **Docker Compose** — оркестрация стенда
- **Zabbix 7** (server, web-frontend на nginx+php, agent2)
- **PostgreSQL 15** (alpine) — backend для Zabbix
- **Telegram Bot API** — алертинг через встроенный webhook media type
- **Zabbix REST API** — автоматизация настройки через `scripts/setup-telegram-action.sh`

## Архитектура

```
                     ┌─────────────────────────────────────────┐
                     │           docker compose                 │
                     │                                          │
   браузер ─:8080───►│   zabbix-web (nginx+php)                 │
                     │         │                                │
                     │         ▼                                │
                     │   zabbix-server  ◄── метрики ─────────── │── zabbix-agent
                     │         │                                │  (мониторит сам себя)
                     │         ▼                                │
                     │   postgres ◄── volume: postgres-data ────│
                     │                                          │
                     └─────────────────────────────────────────┘
                              │
                              ▼ webhook media type
                       Telegram Bot API ──► @ваш_бот ──► вы
```

Сервисы общаются по имени через сеть, которую compose создаёт автоматически. Данные PostgreSQL хранятся в именованном томе `postgres-data` — переживают `docker compose down`.

## Как поднять

### 1. Подготовка

```bash
git clone https://github.com/VZ52/Ubuntu-Zabbix.git
cd Ubuntu-Zabbix
cp .env.example .env
# отредактировать .env: задать POSTGRES_PASSWORD, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
```

Получить Telegram-токен и chat_id:
- Токен бота: написать **@BotFather** → `/newbot`
- chat_id: написать **@userinfobot** → `/start`

### 2. Запуск стека

```bash
docker compose up -d
```

Первый запуск ~3-7 минут (скачивает образы ~600 МБ). Проверить:

```bash
docker compose ps        # все 4 сервиса в статусе running/healthy
```

### 3. Веб-интерфейс

Открыть **http://localhost:8080**, логин `Admin` / `zabbix`.

### 4. Настройка Telegram-алертинга

Сначала через UI:
- **Alerts → Media types → Telegram** → вкладка Parameters → задать `Token` = ваш `TELEGRAM_BOT_TOKEN` → Update
- **Users → Users → Admin → Media** → Add → Type: Telegram, Send to: ваш chat_id → Update

Затем создание action — через скрипт:

```bash
./scripts/setup-telegram-action.sh
```

Скрипт идемпотентный: при повторном запуске не дублирует action.

### 5. Проверка алертинга

```bash
docker stop zbx-agent       # уронить агента
# через 3-5 минут — алерт в Telegram про "Zabbix agent is not available"

docker start zbx-agent      # вернуть в строй
# ещё через 1-2 минуты — recovery-сообщение "Resolved"
```

## Безопасность

- `.env` с секретами — в `.gitignore`, не коммитится
- Пароль БД и токен бота не попадают в `docker-compose.yml` напрямую — только через `${VAR}` из `.env`
- Порт PostgreSQL (5432) не пробрасывается на хост — БД доступна только сервисам compose внутри сети

## Структура

```
.
├── docker-compose.yml             # описание всего стека
├── .env.example                   # шаблон секретов
├── .gitignore                     # исключает .env и системные файлы
├── README.md                      # этот файл
└── scripts/
    └── setup-telegram-action.sh   # автоматизация настройки через Zabbix API
```

## Автор

Зайцев Константин — https://github.com/VZ52
