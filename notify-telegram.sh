#!/bin/bash
# Claude Code → Telegram notification hook
#
# Usage:
#   notify-telegram.sh stop          (Stop hook)
#   notify-telegram.sh notification  (Notification hook)
#   notify-telegram.sh activity      (UserPromptSubmit hook)
#
# Logic:
#   stop         → schedule notification in 30s (cancellable)
#   activity     → cancel any pending notification
#   notification → always send immediately (Claude is blocked)
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN
#   TELEGRAM_CHAT_ID

EVENT="${1:-stop}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"
PENDING_PID="/tmp/claude-pending-notify-pid"
IDLE_DELAY=30

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  exit 0
fi

_send() {
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${1}" \
    > /dev/null 2>&1
}

_cancel_pending() {
  if [ -f "$PENDING_PID" ]; then
    kill "$(cat "$PENDING_PID")" 2>/dev/null
    rm -f "$PENDING_PID"
  fi
}

if [ "$EVENT" = "activity" ]; then
  # User is back — cancel any scheduled notification
  _cancel_pending
  exit 0
fi

if [ "$EVENT" = "stop" ]; then
  # Cancel previous pending (in case of rapid Stop events)
  _cancel_pending
  # Schedule notification after IDLE_DELAY seconds
  ( sleep "$IDLE_DELAY" && rm -f "$PENDING_PID" && _send "✅ Claude 完成工作了，回來看看吧" ) &
  echo $! > "$PENDING_PID"
  exit 0
fi

if [ "$EVENT" = "notification" ]; then
  DETAIL=$(cat 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message', '')
    print(msg[:200] if msg else '')
except:
    print('')
" 2>/dev/null)

  # Same delayed mechanism as stop — cancel existing timer, start a new 30s one.
  # This prevents duplicate/immediate sends when both Stop and Notification fire together.
  _cancel_pending
  if [ -n "$DETAIL" ]; then
    ( sleep "$IDLE_DELAY" && rm -f "$PENDING_PID" && _send "⏸ Claude 需要你確認

$DETAIL" ) &
  else
    ( sleep "$IDLE_DELAY" && rm -f "$PENDING_PID" && _send "✅ Claude 完成工作了，回來看看吧" ) &
  fi
  echo $! > "$PENDING_PID"
  exit 0
fi

exit 0
