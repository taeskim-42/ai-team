#!/bin/bash
# API-based security auditor — uses any OpenAI-compatible endpoint
# Works with: OpenAI, LiteLLM proxy, Azure OpenAI, Gemini via proxy, etc.
#
# Required env vars (set in your shell profile or .env):
#   OPENAI_API_KEY    — API key / bearer token
#   OPENAI_BASE_URL   — (optional) proxy URL, defaults to https://api.openai.com/v1
#   AI_SECURITY_MODEL — (optional) model override, defaults to gpt-4o

export API_BASE="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
export API_KEY="${OPENAI_API_KEY}"
export MODEL="${AI_SECURITY_MODEL:-gpt-4o}"

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="$AGENT_DIR/../../_api-bridge.sh"
TRIGGER="pre-commit"
INPUT="staged"
