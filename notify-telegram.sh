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
#   notification → if message has content, schedule 30s "needs confirmation" (separate timer)
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN
#   TELEGRAM_CHAT_ID

EVENT="${1:-stop}"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"
STOP_PID="/tmp/claude-pending-stop-pid"
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

_cancel_pending() {
  for f in "$STOP_PID" "$NOTIFY_PID"; do
    if [ -f "$f" ]; then
      kill "$(cat "$f")" 2>/dev/null
      rm -f "$f"
    fi
  done
}

if [ "$EVENT" = "activity" ]; then
  # User is back — cancel any scheduled notification
  _cancel_pending
  exit 0
fi

if [ "$EVENT" = "stop" ]; then
  # Cancel previous stop timer (in case of rapid Stop events)
  if [ -f "$STOP_PID" ]; then
    kill "$(cat "$STOP_PID")" 2>/dev/null
    rm -f "$STOP_PID"
  fi
  ( sleep "$IDLE_DELAY" && rm -f "$STOP_PID" && _send "✅ Claude 完成工作了，回來看看吧" ) &
  echo $! > "$STOP_PID"
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

  # Only act when there's actual content — that means Claude is blocked waiting for input.
  # Generic "finished" notifications have no message; those are handled by the stop event.
  if [ -z "$DETAIL" ]; then
    exit 0
  fi

  # Cancel previous notify timer and schedule a new one
  if [ -f "$NOTIFY_PID" ]; then
    kill "$(cat "$NOTIFY_PID")" 2>/dev/null
    rm -f "$NOTIFY_PID"
  fi
  ( sleep "$IDLE_DELAY" && rm -f "$NOTIFY_PID" && _send "⏸ Claude 需要你確認

$DETAIL" ) &
  echo $! > "$NOTIFY_PID"
  exit 0
fi

exit 0
