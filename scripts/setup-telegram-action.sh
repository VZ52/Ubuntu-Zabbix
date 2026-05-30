#!/usr/bin/env bash
# Настраивает в Zabbix action "Telegram alerts" через REST API.
# Idempotent: если action уже существует — выходит без ошибки.
#
# Требуется:
#   - запущенный стек (docker compose up -d)
#   - в Media Type "Telegram" руками прописан токен бота
#   - у пользователя Admin в Media добавлен Telegram с chat_id
#
# Запуск из корня репозитория:
#   ./scripts/setup-telegram-action.sh

set -e

API="${ZABBIX_URL:-http://localhost:8080}/api_jsonrpc.php"
ZBX_USER="${ZABBIX_USER:-Admin}"
ZBX_PASS="${ZABBIX_PASSWORD:-zabbix}"
ACTION_NAME="${ACTION_NAME:-Telegram alerts}"

jq_get() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

echo "==> 1. Логин в Zabbix API"
TOKEN=$(curl -s -X POST -H "Content-Type: application/json-rpc" "$API" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"user.login\",\"params\":{\"username\":\"$ZBX_USER\",\"password\":\"$ZBX_PASS\"},\"id\":1}" \
  | jq_get "d['result']")
echo "    auth token: ${TOKEN:0:16}..."

api() {
  curl -s -X POST \
    -H "Content-Type: application/json-rpc" \
    -H "Authorization: Bearer $TOKEN" \
    "$API" -d "$1"
}

echo "==> 2. Проверяем, есть ли action '$ACTION_NAME'"
EXISTING=$(api "{\"jsonrpc\":\"2.0\",\"method\":\"action.get\",\"params\":{\"filter\":{\"name\":\"$ACTION_NAME\"}},\"id\":1}" \
  | jq_get "len(d['result'])")
if [ "$EXISTING" -gt 0 ]; then
  echo "    action уже существует, выходим (idempotent)"
  exit 0
fi

echo "==> 3. Получаем ID пользователя Admin и Telegram media type"
USERID=$(api "{\"jsonrpc\":\"2.0\",\"method\":\"user.get\",\"params\":{\"output\":[\"userid\"],\"filter\":{\"username\":\"$ZBX_USER\"}},\"id\":1}" \
  | jq_get "d['result'][0]['userid']")
MTID=$(api '{"jsonrpc":"2.0","method":"mediatype.get","params":{"output":["mediatypeid"],"filter":{"name":"Telegram"}},"id":1}' \
  | jq_get "d['result'][0]['mediatypeid']")
echo "    userid=$USERID, telegram mediatypeid=$MTID"

echo "==> 4. Создаём action"
RESULT=$(api "{
  \"jsonrpc\":\"2.0\",
  \"method\":\"action.create\",
  \"params\":{
    \"name\":\"$ACTION_NAME\",
    \"eventsource\":0,
    \"esc_period\":\"1h\",
    \"status\":0,
    \"operations\":[{
      \"operationtype\":0,
      \"esc_period\":\"0\",
      \"esc_step_from\":1,
      \"esc_step_to\":1,
      \"opmessage\":{\"default_msg\":1,\"mediatypeid\":\"$MTID\"},
      \"opmessage_usr\":[{\"userid\":\"$USERID\"}]
    }],
    \"recovery_operations\":[{
      \"operationtype\":0,
      \"opmessage\":{\"default_msg\":1,\"mediatypeid\":\"$MTID\"},
      \"opmessage_usr\":[{\"userid\":\"$USERID\"}]
    }]
  },
  \"id\":1
}")
ACTIONID=$(echo "$RESULT" | jq_get "d['result']['actionids'][0]")
echo "    создан actionid=$ACTIONID"
echo "==> готово"
