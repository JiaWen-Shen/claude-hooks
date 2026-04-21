#!/bin/bash
# PreToolUse hook: block git commit if code files are staged without tests

cmd=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only apply to git commit commands
if ! echo "$cmd" | grep -q 'git commit'; then
  exit 0
fi

# If staged files contain code (not just docs), require tests
if git diff --cached --name-only 2>/dev/null | grep -qE '\.(ts|tsx|js|jsx|py|rs|go|java|swift|kt|sh)$'; then
  printf '{"decision":"block","reason":"Tests must pass before committing code changes. Please run tests first."}'
  exit 0
fi

# Docs-only commit — allow
exit 0
