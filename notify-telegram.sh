#!/bin/bash
# Claude Code → Telegram notification hook
# Usage: notify-telegram.sh <event_type>
#   event_type: stop | notification
#
# Logic:
#   stop       → 延遲 10 秒發送，UserPromptSubmit 可取消
#   notification → 立即發送（Claude 在等使用者操作）
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

INPUT=$(cat 2>/dev/null)
PENDING_PID_FILE="/tmp/claude-pending-notify-pid"
DEBUG_LOG="/tmp/claude-hook-debug.log"

_send_telegram() {
  local text="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${text}" \
    > /dev/null 2>&1
}

if [ "$EVENT" = "stop" ]; then
  # 清掉上一個還沒發出的計時器（如果有的話）
  if [ -f "$PENDING_PID_FILE" ]; then
    kill "$(cat "$PENDING_PID_FILE")" 2>/dev/null
    rm -f "$PENDING_PID_FILE"
  fi

  TEXT="✅ Claude 完成工作了，回來看看吧"
  echo "[$(date)] event=stop → scheduled (10s delay)" >> "$DEBUG_LOG"

  # 背景等 10 秒，期間若 UserPromptSubmit 觸發會 kill 這個 PID
  (
    sleep 10
    rm -f "$PENDING_PID_FILE"
    echo "[$(date)] event=stop → SENT (no response in 10s)" >> "$DEBUG_LOG"
    _send_telegram "$TEXT"
  ) &

  echo $! > "$PENDING_PID_FILE"

elif [ "$EVENT" = "notification" ]; then
  # Notification 代表 Claude 在等使用者確認，立即發送
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

  echo "[$(date)] event=notification → SENT (immediate)" >> "$DEBUG_LOG"
  _send_telegram "$TEXT"
fi

exit 0
