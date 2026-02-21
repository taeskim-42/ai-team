#!/bin/bash
# _api-bridge.sh — OpenAI-compatible API bridge for external agents
#
# Reads a prompt from stdin, sends it to a chat completions API,
# and outputs the assistant's response to stdout.
#
# Required environment variables (export in agent.sh):
#   API_BASE  — Base URL (e.g., https://api.openai.com/v1)
#   API_KEY   — Bearer token
#   MODEL     — Model identifier (e.g., gpt-4o, gemini/gemini-2.5-pro)

set -euo pipefail

if [[ -z "${API_BASE:-}" || -z "${API_KEY:-}" || -z "${MODEL:-}" ]]; then
  echo "ERROR: _api-bridge.sh requires API_BASE, API_KEY, MODEL environment variables." >&2
  echo "Set them in your agent.sh (see external-agents/_template/agent.sh)." >&2
  exit 1
fi

# Save piped stdin to temp file (heredoc would override stdin for python3)
_prompt_file=$(mktemp)
trap 'rm -f "$_prompt_file"' EXIT
cat > "$_prompt_file"

python3 - "$_prompt_file" << 'PYEOF'
import json, urllib.request, ssl, sys, os

with open(sys.argv[1]) as f:
    prompt = f.read()

if not prompt.strip():
    print("ERROR: empty prompt on stdin", file=sys.stderr)
    sys.exit(1)

url = os.environ["API_BASE"].rstrip("/") + "/chat/completions"
payload = json.dumps({
    "model": os.environ["MODEL"],
    "messages": [{"role": "user", "content": prompt}]
}).encode()

req = urllib.request.Request(url, data=payload, headers={
    "Authorization": f"Bearer {os.environ['API_KEY']}",
    "Content-Type": "application/json"
})

try:
    ctx = ssl.create_default_context()
    resp = json.load(urllib.request.urlopen(req, context=ctx, timeout=300))
    print(resp["choices"][0]["message"]["content"])
except urllib.error.HTTPError as e:
    body = e.read().decode(errors="replace")[:500]
    print(f"API HTTP {e.code}: {body}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"API call failed: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
