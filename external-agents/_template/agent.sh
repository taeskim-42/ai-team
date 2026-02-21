#!/bin/bash
# External Agent Configuration
# Copy this directory and customize for your LLM.

# ── Mode 1: CLI ──────────────────────────────────────────────
# Pipe stdin to a CLI tool (must accept stdin, output to stdout).
# Examples:
#   COMMAND="gemini -m gemini-2.5-pro"
#   COMMAND="codex --model o3"
#   COMMAND="ollama run llama3"
#   COMMAND="openai chat -m gpt-4o"
COMMAND=""

# ── Mode 2: API ──────────────────────────────────────────────
# Use _api-bridge.sh with any OpenAI-compatible endpoint.
# Uncomment and set these, then set COMMAND to the bridge:
#
#   export API_BASE="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
#   export API_KEY="${OPENAI_API_KEY}"
#   export MODEL="gpt-4o"
#   AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   COMMAND="$AGENT_DIR/../_api-bridge.sh"
#
# Works with: OpenAI, LiteLLM, Azure OpenAI, Gemini proxy, etc.

# When to trigger this agent
# Options: task-completed | pre-commit | on-demand
TRIGGER="task-completed"

# What input to feed the LLM
# Options:
#   changed-files  — full content of changed files
#   full-diff      — git diff output
#   staged         — staged files content
INPUT="changed-files"
