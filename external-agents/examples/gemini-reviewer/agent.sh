#!/bin/bash
# Gemini — Long-context code reviewer
# Leverages Gemini's 1M+ token context window for whole-file review.

COMMAND="gemini -m gemini-2.5-pro"
TRIGGER="task-completed"
INPUT="changed-files"
