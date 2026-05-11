#!/bin/bash
# PostToolUse hook: write /tmp/tests-passed when a test command appears to have passed.
#
# 為什麼不直接看 exit code？
# Claude Code 不同版本對 PostToolUse 的 tool_response payload 結構不一：
#   - 有版本提供 exit_code / exitCode
#   - 有版本只提供 stdout / stderr 與 interrupted
#   - 部分版本把訊息塞在 content 陣列裡
# 直接信任 exit_code 在新版會抓不到（field 不存在 → -1）。
# 改為「stdout/stderr 含通過 marker + 不含失敗 marker」就視為通過，
# 此策略對所有測試框架皆穩定，且 fail-safe（抓不到就不寫，等 user 重跑）。

input=$(cat)

# 1) 確認這次是測試指令
cmd=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

if ! echo "$cmd" | grep -qE '(npm (run )?test|pnpm (run )?test|yarn (run )?test|bun test|pytest|vitest|jest|cargo test|go test|mix test)'; then
  exit 0
fi

# 2) 從 tool_response 抽出文字輸出（容錯多種 schema）
output=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', {}) or {}
    parts = []
    # 直接欄位
    for k in ('stdout', 'stderr', 'output', 'text'):
        v = r.get(k)
        if isinstance(v, str):
            parts.append(v)
    # content array (anthropic-style)
    content = r.get('content')
    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict):
                t = item.get('text')
                if isinstance(t, str):
                    parts.append(t)
            elif isinstance(item, str):
                parts.append(item)
    # 若整個 tool_response 是字串（極簡格式）
    if isinstance(d.get('tool_response'), str):
        parts.append(d['tool_response'])
    print('\n'.join(parts))
except Exception:
    pass
" 2>/dev/null)

# 3) Pattern 偵測：包含通過 marker 且不含失敗 marker
#    各 framework 通過時都會印 'X passed'/'X passing'/'X pass'/'ok'
#    失敗時印 'FAIL'/'failed'/'failures:'/'error:' 等

has_pass=$(echo "$output" | grep -ciE '([0-9]+ (passed|passing|pass\b)|^ok[[:space:]]|tests:.*passed)')
has_fail=$(echo "$output" | grep -ciE '([0-9]+ (failed|failing)|^FAIL\b|^FAILED\b|tests:.*failed|^E[[:space:]]+[A-Z]|panicked at)')

# 若 output 為空（payload 解析全失敗）→ fallback：看 exit_code 欄位
if [ -z "$output" ]; then
  exit_code=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', {}) or {}
    print(r.get('exit_code', r.get('exitCode', r.get('returncode', -1))))
except Exception:
    print(-1)
" 2>/dev/null)
  if [ "$exit_code" = "0" ]; then
    date +%s > /tmp/tests-passed
  fi
  exit 0
fi

if [ "$has_pass" -gt 0 ] && [ "$has_fail" -eq 0 ]; then
  date +%s > /tmp/tests-passed
fi

exit 0
