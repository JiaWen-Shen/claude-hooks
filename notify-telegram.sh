#!/bin/bash
# Claude Code → Telegram notification hook
# Usage: notify-telegram.sh <event_type>
#   event_type: stop | notification
#
# Env vars required:
#   TELEGRAM_BOT_TOKEN
#   TELEGRAM_CHAT_ID

EVENT="${1:-stop}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID:-186906335}"

if [ -z "$BOT_TOKEN" ]; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat 2>/dev/null)

# Only notify if user has been inactive for more than 10 seconds
LAST_ACTIVITY_FILE="/tmp/claude-last-user-activity"
if [ -f "$LAST_ACTIVITY_FILE" ]; then
  LAST_ACTIVITY=$(cat "$LAST_ACTIVITY_FILE" 2>/dev/null)
  NOW=$(date +%s)
  ELAPSED=$((NOW - LAST_ACTIVITY))
  if [ "$ELAPSED" -lt 10 ]; then
    exit 0
  fi
fi

if [ "$EVENT" = "notification" ]; then
  # Extract message from input JSON
  DETAIL=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message', '')
    print(msg[:200] if msg else '')
except:
    print('')
" 2>/dev/null)

  if [ -n "$DETAIL" ]; then
    TEXT="⏸ Claude 需要你確認

$DETAIL"
  else
    TEXT="⏸ Claude 需要你確認，請回來看看"
  fi
else
  # Stop event
  TEXT="✅ Claude 完成工作了，回來看看吧"
fi

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${TEXT}" \
  > /dev/null 2>&1

exit 0
