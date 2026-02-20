#!/bin/bash
# External Agent Configuration
# Copy this directory and customize for your LLM.

# CLI command to invoke the LLM
# Examples:
#   "gemini -m gemini-2.5-pro"
#   "codex --model o3"
#   "ollama run llama3"
#   "openai chat -m gpt-4o"
COMMAND=""

# When to trigger this agent
# Options: task-completed | pre-commit | on-demand
TRIGGER="task-completed"

# What input to feed the LLM
# Options:
#   changed-files  — full content of changed files
#   full-diff      — git diff output
#   staged         — staged files content
INPUT="changed-files"
