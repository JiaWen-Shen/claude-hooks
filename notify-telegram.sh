#!/bin/bash
# Claude Code → Telegram notification hook
#
# Usage:
#   notify-telegram.sh stop          (Stop hook)
#   notify-telegram.sh notification  (Notification hook)
#   notify-telegram.sh activity      (UserPromptSubmit hook)
#
# Logic:
#   stop         → send "✅ 完成工作了" immediately; cancel any pending confirm timer
#   notification → if Stop fired within 3s: ignore (already notified by stop)
#                  else: schedule "⏸ 需要你確認" after 30s (cancellable)
#   activity     → cancel pending confirm timer
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN
#   TELEGRAM_CHAT_ID

EVENT="${1:-stop}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"
STOP_RECENT="/tmp/claude-stop-recent"
NOTIFY_PID="/tmp/claude-pending-notify-pid"
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

_cancel_confirm() {
  if [ -f "$NOTIFY_PID" ]; then
    kill "$(cat "$NOTIFY_PID")" 2>/dev/null
    rm -f "$NOTIFY_PID"
  fi
}

if [ "$EVENT" = "activity" ]; then
  _cancel_confirm
  exit 0
fi

if [ "$EVENT" = "stop" ]; then
  _cancel_confirm
  date +%s > "$STOP_RECENT"
  _send "✅ Claude 完成工作了，回來看看吧"
  exit 0
fi

if [ "$EVENT" = "notification" ]; then
  # Suppress if Stop fired within the last 3 seconds —
  # Notification fires together with Stop on task complete; Stop already sent the message.
  if [ -f "$STOP_RECENT" ]; then
    STOP_TIME=$(cat "$STOP_RECENT" 2>/dev/null)
    NOW=$(date +%s)
    if [ $((NOW - STOP_TIME)) -le 3 ]; then
      exit 0
    fi
    rm -f "$STOP_RECENT"
  fi

  DETAIL=$(cat 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    msg = d.get('message', '')
    print(msg[:200] if msg else '')
except:
    print('')
" 2>/dev/null)

  if [ -z "$DETAIL" ]; then
    exit 0
  fi

  _cancel_confirm
  ( sleep "$IDLE_DELAY" && rm -f "$NOTIFY_PID" && _send "⏸ Claude 需要你確認

$DETAIL" ) &
  echo $! > "$NOTIFY_PID"
  exit 0
fi

exit 0
