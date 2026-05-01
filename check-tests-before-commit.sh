#!/bin/bash
# PreToolUse hook: block git commit if code files are staged without recent tests

cmd=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only apply to git commit commands
if ! echo "$cmd" | grep -q 'git commit'; then
  exit 0
fi

# Docs-only commit — allow without tests
if ! git diff --cached --name-only 2>/dev/null | grep -qE '\.(ts|tsx|js|jsx|py|rs|go|java|swift|kt|sh)$'; then
  exit 0
fi

# Check if tests were run recently (within 10 minutes)
if [ -f /tmp/tests-passed ]; then
  last_run=$(cat /tmp/tests-passed)
  now=$(date +%s)
  age=$((now - last_run))
  if [ "$age" -le 600 ]; then
    exit 0
  fi
fi

printf '{"decision":"block","reason":"Tests must pass before committing code changes. Run npm test / bun test / pytest first."}'
exit 0
