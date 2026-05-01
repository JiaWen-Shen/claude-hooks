#!/bin/bash
# PostToolUse hook: write /tmp/tests-passed when a test command exits 0

input=$(cat)

cmd=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null)

# Only care about test commands
if ! echo "$cmd" | grep -qE '(npm test|bun test|pytest|vitest|jest|cargo test|go test)'; then
  exit 0
fi

# Check exit code from tool response
exit_code=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
resp = d.get('tool_response', {})
# exit_code may be in different fields depending on version
print(resp.get('exit_code', resp.get('exitCode', -1)))
" 2>/dev/null)

if [ "$exit_code" = "0" ]; then
  date +%s > /tmp/tests-passed
fi

exit 0
