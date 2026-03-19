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

SUPPRESS_FILE="/tmp/claude-suppress-next"
LAST_STOP_FILE="/tmp/claude-last-stop"
DEBUG_LOG="/tmp/claude-hook-debug.log"

# If Stop fires: check suppress flag first, then write last_stop timestamp
if [ "$EVENT" = "stop" ]; then
  if [ -f "$SUPPRESS_FILE" ]; then
    rm -f "$SUPPRESS_FILE"
    echo "[$(date)] event=stop → SUPPRESS (user responded within 10s)" >> "$DEBUG_LOG"
    exit 0
  fi
  date +%s > "$LAST_STOP_FILE"
  echo "[$(date)] event=stop → SEND (writing last_stop)" >> "$DEBUG_LOG"
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
