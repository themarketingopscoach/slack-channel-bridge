#!/bin/zsh
# Start the Slack bridge session for Abi's MBUG-14 questions.
# Locked down: built-in tools limited to Read/Glob/Grep (no Bash, Edit, Write, WebFetch); the Render plugin,
# claude.ai connectors, Claude in Chrome and computer use switched off, so the only MCP server is this
# folder's Slack bridge.
# (--restricted and --strict-mcp-config can't be used: either one makes the development-channel flag
# report "server:slack · no MCP server configured with that name" and Slack messages would be dropped.)
cd "${0:A:h}" || exit 1
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
export SLACK_CHANNEL_LOG_FILE="$HOME/.claude/channels/slack/bridge.log"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
REVIEW="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop/Claude Code/Envoy/mbug14-video-review-2026-10-26"
args=(
  --dangerously-load-development-channels server:slack
  --settings '{"enabledMcpjsonServers":["slack"],"enabledPlugins":{"render@claude-plugins-official":false}}'
  --tools Read,Glob,Grep
  --no-chrome
  --disallowedTools mcp__claude-in-chrome,mcp__computer-use
  --allowedTools mcp__slack__reply
  --add-dir "$REVIEW"
  --append-system-prompt "$(cat roles/mbug14-abi.md)"
  -n "MBUG-14 Slack bridge (Abi)"
)
exec claude "${args[@]}"
