#!/bin/zsh
# Start the Slack bridge session for Abi, covering MBUG-14 (Envoy), the OneSignal $150 incentive MQL work, and
# Brandon's Algolia ticket notes (roles/algolia-abi.md, added 2026-10-27).
# Replaces run-mbug14-bridge.sh while both topics are open. Run only one bridge session at a time: two sessions on
# the same Slack app both receive every event and would answer twice.
# Locked down like the MBUG-14 launcher: Read/Glob/Grep plus Bash, and Bash is auto-allowed only for the read-only
# ./check-onesignal150.sh. Any other command opens a permission prompt, which relays to Brandon's DM only.
# Usage: ./run-abi-bridge.sh ["opening instruction for the session"]
cd "${0:A:h}" || exit 1
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
export SLACK_CHANNEL_LOG_FILE="$HOME/.claude/channels/slack/bridge.log"
export ENABLE_CLAUDEAI_MCP_SERVERS=false
REVIEW="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop/Claude Code/Envoy/mbug14-video-review-2026-10-26"
ONESIGNAL="$HOME/Desktop/Temp Claude/OneSignal/Incentive 150 Sequencing/bot"
# Algolia ticket folders Abi may ask about (added 2026-10-27; read-only, see roles/algolia-abi.md)
ALG="$HOME/Desktop/Temp Claude/Algolia"
ALGOLIA_DIRS=(
  "$ALG/Abi bridge context (2026-10-27)"
  "$ALG/Build Clinic forms MOS-2978 (2026-10-26)"
  "$ALG/Mackenzie Shopify B2B tickets (2026-10-26)"
  "$ALG/NRF Lounge form MOS-2944 (2026-10-09)"
  "$ALG/MOS-2947 + MOS-2889 email builds (2026-10-20)"
  "$ALG/MOS-2931 Ask AI deprecation email (2026-10-23)"
  "$ALG/MKTSM list uploads 5685-5686-5688 (2026-10-19)"
  "$ALG/MKTSM list uploads 5708-5711-5720 (2026-10-23)"
  "$ALG/MKTSM-5692 ContentCon US prep (2026-10-19)"
)
alg_add=()
for d in "${ALGOLIA_DIRS[@]}"; do alg_add+=(--add-dir "$d"); done
SCOPE='# Scope of this session

You cover three topics for Abi: Envoy ticket MBUG-14 (first role below), the OneSignal $150 incentive MQL fix (second role below), and the Algolia tickets listed in the third role below. Keep them apart: answer each from its own sources, and never mix Envoy, OneSignal and Algolia details in one reply. Where a role says to decline anything other than its own topic, read that as anything other than these three topics.
'
args=(
  --dangerously-load-development-channels server:slack
  --settings '{"enabledMcpjsonServers":["slack"],"enabledPlugins":{"render@claude-plugins-official":false}}'
  --tools Read,Glob,Grep,Bash
  --no-chrome
  --disallowedTools mcp__claude-in-chrome,mcp__computer-use
  --allowedTools mcp__slack__reply "Bash(./check-onesignal150.sh)"
  --add-dir "$REVIEW"
  --add-dir "$ONESIGNAL"
  "${alg_add[@]}"
  --append-system-prompt "$SCOPE
$(cat roles/mbug14-abi.md)

$(cat roles/onesignal150-abi.md)

$(cat roles/algolia-abi.md)"
  -n "Abi Slack bridge (MBUG-14 + OneSignal 150 + Algolia)"
)
# Pinned to 2.1.311 (2026-10-28): on 2.1.312 Slack events still arrive but the session never gets the
# mcp__slack__reply tool, so it can't answer. Falls back to `claude` if the old version has been cleaned up.
CLAUDE_BIN="$HOME/.local/share/claude/versions/2.1.311"
[[ -x "$CLAUDE_BIN" ]] || CLAUDE_BIN=claude
exec "$CLAUDE_BIN" "${args[@]}" "$@"
