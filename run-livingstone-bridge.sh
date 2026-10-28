#!/bin/zsh
# Start the Slack bridge session for Livingstone Masango's OneSignal RevenueCat / LeanData questions
# (roles/onesignal-leandata-livingstone.md, added 2026-10-28).
# Run only one bridge session at a time: two sessions on the same Slack app both receive every event and would
# answer twice. Stop Abi's bridge (run-abi-bridge.sh) before starting this one.
# Uses its own allowlist, access-livingstone.json (Brandon + Livingstone), so access.json stays set up for Abi.
# Locked down: Read/Glob/Grep only, no Bash. Any other tool opens a permission prompt, which relays to Brandon's
# DM only. Sonnet at low effort because Brandon asked for a token limit.
# Usage: ./run-livingstone-bridge.sh ["opening instruction for the session"]
cd "${0:A:h}" || exit 1
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
export SLACK_CHANNEL_LOG_FILE="$HOME/.claude/channels/slack/bridge.log"
export SLACK_ACCESS_FILE="${0:A:h}/access-livingstone.json"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
# Load MCP tools up front. With tool search on, mcp__slack__reply is deferred behind ToolSearch, which --tools
# below leaves out, so the session can't reply (seen 2026-10-28 on 2.1.312 with Sonnet).
export ENABLE_TOOL_SEARCH=false
REVCAT="$HOME/Desktop/Temp Claude/OneSignal/RevenueCat Event Upload"
args=(
  --dangerously-load-development-channels server:slack
  --settings '{"enabledMcpjsonServers":["slack"],"enabledPlugins":{"render@claude-plugins-official":false}}'
  --tools Read,Glob,Grep,mcp__slack__reply
  --no-chrome
  --disallowedTools mcp__claude-in-chrome,mcp__computer-use
  --allowedTools mcp__slack__reply
  --add-dir "$REVCAT"
  --add-dir "$HOME/Desktop/Temp Claude/OneSignal/Meetings"
  --model sonnet
  --effort low
  --append-system-prompt "$(cat roles/onesignal-leandata-livingstone.md)"
  -n "Livingstone Slack bridge (OneSignal RevCat LeanData)"
)
# Pinned to 2.1.311: on 2.1.312 (installed 2026-10-28) Slack events still arrive but the session never gets the
# mcp__slack__reply tool, so it can't answer. Abi's bridge on 2.1.311 replied fine. Falls back to `claude` if the
# old version has been cleaned up.
CLAUDE_BIN="$HOME/.local/share/claude/versions/2.1.311"
[[ -x "$CLAUDE_BIN" ]] || CLAUDE_BIN=claude
exec "$CLAUDE_BIN" "${args[@]}" "$@"
