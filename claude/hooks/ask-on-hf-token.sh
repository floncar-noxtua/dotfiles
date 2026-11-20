#!/bin/bash
# PreToolUse hook for Bash: force a permission prompt when the command mentions HF_TOKEN.
cmd=$(jq -r '.tool_input.command // empty')
if [[ "$cmd" == *HF_TOKEN* ]]; then
  jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: "Command references HF_TOKEN - needs your approval"}}'
fi
exit 0
