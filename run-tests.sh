#!/bin/bash
# PostToolUse hook: 偵測被編輯的檔案，往上找最近的 package.json
# 若有 test script，跑 CI=true npm test
# asyncRewake 模式：測試失敗 exit 2，Claude 會被喚醒通知
#
# Debounce：連續編輯多個檔案時，只在最後一次觸發後 2 秒才真正跑測試。
# 避免中間狀態的失敗誤報。

# 讀取被編輯的檔案路徑
f=$(jq -r '.tool_input.file_path // ""')

# 只對 JS/TS 原始碼檔案觸發
echo "$f" | grep -qE '\.(ts|tsx|js|jsx|mjs|cjs)$' || exit 0

# 往上尋找有 test script 的 package.json
dir=$(dirname "$f")
while [ "$dir" != "/" ]; do
  if [ -f "$dir/package.json" ] && jq -e '.scripts.test' "$dir/package.json" > /dev/null 2>&1; then
    # Debounce：寫入 timestamp，等 2 秒後確認沒有更新的觸發才執行
    lock_dir="/tmp/run-tests-debounce"
    mkdir -p "$lock_dir"
    lock_file="$lock_dir/$(echo "$dir" | md5sum | cut -d' ' -f1)"
    ts=$(date +%s%N)  # nanoseconds
    echo "$ts" > "$lock_file"
    sleep 2
    stored=$(cat "$lock_file" 2>/dev/null)
    [ "$stored" != "$ts" ] && exit 0  # 有更新的觸發，這次跳過

    cd "$dir"
    CI=true npm test 2>&1
    code=$?
    [ $code -ne 0 ] && exit 2
    exit 0
  fi
  dir=$(dirname "$dir")
done

exit 0
