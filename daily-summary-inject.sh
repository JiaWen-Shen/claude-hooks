#!/usr/bin/env bash
# daily-summary-inject.sh
# UserPromptSubmit hook — 偵測「開始工作」並自動注入前一天的工作摘要

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

SUMMARY_DIR="$HOME/Jottacloud/vibe/daily-summaries"
TODAY=$(date +%Y-%m-%d)

if echo "$PROMPT" | grep -qE "開始工作|start work"; then
  # 找最新的摘要檔，排除今天的（今天才剛開始）
  LATEST=$(ls -1 "$SUMMARY_DIR"/*.md 2>/dev/null | grep -v "$TODAY" | sort | tail -1)

  if [ -n "$LATEST" ]; then
    DATE=$(basename "$LATEST" .md)
    CONTENT=$(cat "$LATEST")
    # 用 jq 安全地 encode，避免特殊字元爆掉 JSON
    CONTEXT=$(printf "=== 上次工作摘要（%s）===\n%s" "$DATE" "$CONTENT" | jq -Rs .)
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}\n' "$CONTEXT"
  else
    printf '{}\n'
  fi
else
  printf '{}\n'
fi
