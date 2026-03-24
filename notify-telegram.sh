#!/bin/bash
# Claude Code → Telegram notification hook
#
# Usage:
#   notify-telegram.sh stop          (Stop hook)
#   notify-telegram.sh notification  (Notification hook)
#   notify-telegram.sh activity      (UserPromptSubmit hook)
#
# Logic:
#   activity     → record timestamp to /tmp/claude-last-activity
#   stop         → only notify if idle > IDLE_THRESHOLD seconds
#   notification → always notify (Claude is blocked waiting for user)
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN
#   TELEGRAM_CHAT_ID

EVENT="${1:-stop}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"
ACTIVITY_FILE="/tmp/claude-last-activity"
IDLE_THRESHOLD=30

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  exit 0
fi

# Record user activity timestamp — no notification needed
if [ "$EVENT" = "activity" ]; then
  date +%s > "$ACTIVITY_FILE"
  exit 0
fi

_send() {
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${1}" \
    > /dev/null 2>&1
}

if [ "$EVENT" = "stop" ]; then
  # Check idle time
  if [ -f "$ACTIVITY_FILE" ]; then
    LAST=$(cat "$ACTIVITY_FILE")
    NOW=$(date +%s)
    IDLE=$((NOW - LAST))
    if [ "$IDLE" -lt "$IDLE_THRESHOLD" ]; then
      exit 0  # User is active, skip notification
    fi
  fi
  _send "✅ Claude 完成工作了，回來看看吧"

elif [ "$EVENT" = "notification" ]; then
  DETAIL=$(cat 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message', '')
    print(msg[:200] if msg else '')
except:
    print('')
" 2>/dev/null)

  if [ -n "$DETAIL" ]; then
    _send "⏸ Claude 需要你確認

$DETAIL"
  else
    _send "⏸ Claude 需要你確認，請回來看看"
  fi
fi

exit 0
