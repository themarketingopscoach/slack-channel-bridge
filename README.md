# Slack channel for Claude Code

A [Claude Code channel](https://code.claude.com/docs/en/channels.md) that lets allowlisted Slack users talk to a **running local Claude Code session** and get replies back in the same Slack thread, including buttons they can click.

```
Slack ──(Socket Mode, outbound WebSocket)──▶ slack-channel.ts ──(stdio MCP)──▶ your Claude Code session
Slack ◀──(Web API chat.postMessage)──────── `reply` tool      ◀──(tool call)── Claude
```

Because Slack Socket Mode connects *out* from this Mac, nothing is exposed on the network and no public URL, ngrok or relay is needed. Events only arrive while the Claude Code session that spawned the bridge is open.

What it does:

- Forwards messages (`message.channels`, `message.groups`, `message.im`, `message.mpim`) and `@mentions` from **allowlisted Slack users only** (`access.json`) into the session as `<channel source="slack" kind="message" …>` events. Everyone else, including the bot itself, is dropped silently.
- Gives Claude a `reply` tool that posts into the originating thread, optionally with Block Kit buttons. A click comes back as a `<channel source="slack" kind="button" …>` event, and the buttons are replaced by the chosen label so they are single-use.
- Optionally relays Claude Code **permission prompts** to the owner's Slack DM with Allow/Deny buttons. Only users listed as `permissionApprovers` can answer; a colleague on the allowlist cannot approve tool use.

## Prerequisites

| Need | Why |
| --- | --- |
| Claude Code ≥ 2.1.234, authenticated with claude.ai or a Console API key | Channels are a research preview; not available on Bedrock, Vertex or Foundry. |
| Channels enabled for your org (Team/Enterprise only) | Owners enable them under *Organization settings → Claude Code → Channels*. Pro/Max accounts need nothing. |
| [Bun](https://bun.sh) on `PATH` | Installed to `~/.bun/bin` on this Mac; `~/.zshrc` already exports it. Open a new terminal or run `exec zsh`. |
| A Slack app in the workspace (steps below) | Supplies the two tokens. |

## 1. Create the Slack app (one-time)

**Done on 2026-10-26.** The app *Claude Code* (app id `A0CC0V6CWH1`) is installed in **Marketo Pros Consulting** (team `T01DRM4CLTX`); its bot user is `@claude_code` (`U0CC1TX1BCM`). Manage it at <https://api.slack.com/apps/A0CC0V6CWH1>. Both tokens are already in `~/.claude/channels/slack/.env`. The steps below are only needed to recreate it.

1. Open <https://api.slack.com/apps> → **Create New App** → **From a manifest** → pick the **Marketo Pros** workspace.
2. Switch the editor to **JSON** and paste the manifest below → **Next** → **Create**.
3. **Basic Information → App-Level Tokens → Generate Token and Scopes**: name it `socket`, add scope `connections:write`, **Generate**. Copy the `xapp-…` token.
4. **Install App → Install to Workspace** → Allow. Copy the **Bot User OAuth Token** (`xoxb-…`) from *OAuth & Permissions*.
5. In Slack, invite the bot to any channel it should listen in: `/invite @claude_code`. DMs to the bot (sidebar → Apps → Claude Code) work without an invite.

Manifest (Socket Mode on, Interactivity on, bot events subscribed):

```json
{
  "display_information": {
    "name": "Claude Code",
    "description": "Bridge to a local Claude Code session",
    "background_color": "#1f1f1f"
  },
  "features": {
    "bot_user": { "display_name": "Claude Code", "always_online": false },
    "app_home": { "messages_tab_enabled": true, "messages_tab_read_only_enabled": false }
  },
  "oauth_config": {
    "scopes": {
      "bot": [
        "chat:write",
        "channels:history",
        "groups:history",
        "im:history",
        "mpim:history",
        "app_mentions:read",
        "users:read",
        "im:write"
      ]
    }
  },
  "settings": {
    "event_subscriptions": {
      "bot_events": ["message.channels", "message.groups", "message.im", "message.mpim", "app_mention"]
    },
    "interactivity": { "is_enabled": true },
    "org_deploy_enabled": false,
    "socket_mode_enabled": true,
    "token_rotation_enabled": false
  }
}
```

Scope notes: `users:read` resolves user ids to display names for the `user_name` attribute. `im:write` lets the bridge open the approver's DM (`conversations.open`) for permission relay; without it the bridge falls back to posting to the user id directly. `app_home.messages_tab_enabled` is what allows people to DM the bot at all.

## 2. Put the tokens in place

Tokens live **only** in `~/.claude/channels/slack/.env` (owner-only permissions; the bridge re-applies `chmod 600` on start and never prints the values). The file already exists as a template:

```bash
open -e ~/.claude/channels/slack/.env
```

```
SLACK_APP_TOKEN=xapp-...
SLACK_BOT_TOKEN=xoxb-...
```

A real environment variable of the same name takes precedence over the file. See [`env.example`](env.example) for the optional settings.

## 3. Who may talk to the session: `access.json`

```json
{
  "allowFrom": ["U01DV0DK1U3", "U040WJ0TN2Y"],
  "permissionApprovers": ["U01DV0DK1U3"],
  "requireMentionInChannels": false
}
```

| Key | Meaning |
| --- | --- |
| `allowFrom` | Slack **user** ids whose messages and button clicks reach Claude. Gating is on the sender, never the channel, so nobody else in a shared channel can inject text. Pre-filled with Brandon (`U01DV0DK1U3`) and Abi Mendoza (`U040WJ0TN2Y`). |
| `permissionApprovers` | Users who receive relayed permission prompts in their DM and whose Allow/Deny counts. Brandon only. Set to `[]` to disable relay. |
| `requireMentionInChannels` | `false` (default): every message from an allowlisted user in a channel the bot is in is forwarded. `true`: in channels only `@Claude Code` mentions and follow-ups in threads Claude is already in are forwarded (DMs always are). Turn this on if the bot sits in a busy channel. |

The file is re-read on every event, so edits apply without a restart. Only the person at the terminal edits it; Claude is instructed to refuse Slack messages asking it to change access or approve tools.

## 4. Run

From this folder (so Claude Code picks up `.mcp.json`):

```bash
cd "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop/Claude Code/slack-channel" && claude --dangerously-load-development-channels server:slack
```

First run only: accept the full-screen development-channels warning (**I am using this for local development**) and the **New MCP server found in this project: slack → Use this MCP server** prompt. Under the banner you should then see:

```
Channels (experimental) messages from server:slack inject directly in this session · restart without --dangerously-load-development-channels to stop
```

The bridge logs `connected as @claude_code (U0CC1TX1BCM) in Marketo Pros Consulting` on stderr. Claude Code only shows a channel server's stderr under `claude --debug` (in `~/.claude/debug/<session-id>.txt`), so to watch the bridge set `SLACK_CHANNEL_LOG_FILE`, for example:

```bash
SLACK_CHANNEL_LOG_FILE=~/.claude/channels/slack/bridge.log claude --dangerously-load-development-channels server:slack
```

and `tail -f ~/.claude/channels/slack/bridge.log` in another terminal. `/mcp` shows the server status.

**Events only arrive while that session is open.** Close it and Slack messages to the bot go nowhere (Slack keeps them, but they are not replayed). Two sessions started with the flag would both receive every event, so run one at a time.

Development-flag sessions must be interactive: `-p` / headless mode ignores the flag.

## 5. Use it

- DM the bot, or post / `@Claude Code` in a channel the bot is in. In the terminal the event shows as a line like `← slack · …`; Claude sees:

  ```
  <channel source="slack" kind="message" channel_id="C0…" channel_type="channel" thread_ts="1761…" message_ts="1761…" user_id="U040WJ0TN2Y" user_name="Abi Mendoza" ts="2026-10-26T…Z">
  can you summarize the open MBUG tickets?
  </channel>
  ```

- Claude answers with `reply(channel_id, thread_ts, text, buttons?)`. The reply lands in the same thread. Markdown is converted to Slack mrkdwn (`**bold**` → `*bold*`, headings, links, bullets); long replies are split across messages.
- Buttons: Claude passes `buttons: [{label, value}]` (up to 10, optional `style: primary|danger`). A click arrives as

  ```
  <channel source="slack" kind="button" action_id="choice_0" action_value="approve" channel_id="C0…" thread_ts="1761…" message_ts="1761…" user_id="U01DV0DK1U3" user_name="Brandon Benjamin" ts="…">
  Clicked "Approve"
  </channel>
  ```

  and the original message's buttons are replaced with `☑️ Approve · @Brandon`.
- Files attached to a Slack message are **not** downloaded; the event carries `[files attached: name.csv]` so Claude can ask for the contents another way.
- Slack escapes `<`, `>` and `&` in message text, so a sender cannot forge a closing `</channel>` tag inside the body; meta values are sanitised the same way.

## 6. Permission relay (owner only)

When Claude Code opens a tool-approval dialog in the terminal, the bridge posts the same prompt to each `permissionApprovers` user's DM with the bot:

> 🔐 **Claude Code wants to run** `Bash`
> *description*
> ```input preview```
> Request `abcde` · use the buttons, or reply `yes abcde` / `no abcde`
> [✅ Allow] [❌ Deny]

Whichever answer arrives first, terminal or Slack, wins. Clicks from anyone not in `permissionApprovers` are ignored and logged (Abi can talk to the session but cannot approve tool use). Only the DM between the approver and the bot receives prompts.

To turn relay off without editing `access.json`:

```bash
SLACK_PERMISSION_RELAY=off claude --dangerously-load-development-channels server:slack
```

(or put `SLACK_PERMISSION_RELAY=off` in the `.env`). When off, the server does not declare the `claude/channel/permission` capability, so Claude Code never sends it prompts.

Relay covers tool approvals (Bash, Write, Edit, MCP tools). Project-trust and MCP-consent dialogs never relay. In **auto** permission mode the classifier decides most calls and no dialog opens; switch to manual mode (Shift+Tab) if you want to see relay in action.

## Settings reference

| Variable | Default | Effect |
| --- | --- | --- |
| `SLACK_APP_TOKEN` | required | App-level token (`xapp-…`) with `connections:write`. |
| `SLACK_BOT_TOKEN` | required | Bot token (`xoxb-…`). |
| `SLACK_PERMISSION_RELAY` | on | `off` / `0` / `false` / `no` disables permission relay. |
| `SLACK_LOG_LEVEL` | `warn` | Slack SDK log level on stderr (`debug` shows every WebSocket frame). |
| `SLACK_CHANNEL_LOG_FILE` | unset | Also append bridge log lines (ids, names, lengths; never message text or tokens) to this file. |
| `SLACK_ACCESS_FILE` | `./access.json` | Alternative allowlist location. |
| `SLACK_CHANNEL_STATE_DIR` | `~/.claude/channels/slack` | Where `.env` is read from (respects `CLAUDE_CONFIG_DIR`). |

## Development

```bash
bun install        # dependencies (already done)
bun test           # routing logic with Slack and MCP stubbed
bun run typecheck  # tsc --noEmit
```

Files: [`slack-channel.ts`](slack-channel.ts) (the whole server), [`slack-channel.test.ts`](slack-channel.test.ts), [`access.json`](access.json), [`.mcp.json`](.mcp.json), [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) (so it can later be published as `plugin:slack@<marketplace>`).

stdout is the MCP transport. The Slack SDKs' default console logger is replaced with a stderr logger for that reason; never add a `console.log`.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `/mcp` shows `slack` as failed, nothing in stderr | `bun` not on `PATH` for the shell that launched `claude`. Open a new terminal (`~/.zshrc` exports `~/.bun/bin`) or change `.mcp.json` to `"command": "${HOME}/.bun/bin/bun"`. |
| stderr: `SLACK_APP_TOKEN … required` | `.env` is empty or at the wrong path. |
| stderr: `Slack connect failed: invalid_auth` (retries every 5–60 s) | Wrong bot token, or the app was never installed to the workspace. Fix the token; no restart needed, the bridge keeps retrying. |
| stderr: `Slack connect failed: not_allowed_token_type` | The two tokens are swapped (app token must start `xapp-`). |
| Message sent, no `← slack` line | Sender not in `allowFrom`; bot not in that channel; message has a subtype (edit, join); or the session is not running with the development flag. Check `/mcp`, then `claude --debug`. |
| `reply failed: not_in_channel` | `/invite @claude_code` into the channel. |
| `reply failed: missing_scope` | The app's scopes changed after install: reinstall the app from *OAuth & Permissions*. |
| Startup says blocked by org policy | A Team/Enterprise Owner must enable Channels for the organization. |
| Permission prompts never reach Slack | Session is in auto mode (no dialog opens), `SLACK_PERMISSION_RELAY=off`, or `permissionApprovers` is empty. |

## Security notes

- Sender gating is by Slack **user id** on every event, including button clicks; channel membership grants nothing.
- Permission verdicts are accepted only from `permissionApprovers`, and the bridge checks the clicker's id, not the message's location.
- `description` and `input_preview` in relayed prompts are sanitised by Claude Code before they reach the bridge, but treat them as untrusted when reading them in Slack.
- The bridge exits when the session's stdio closes, so an orphaned process never keeps acknowledging (and silently swallowing) Slack events.
- Nothing is written to disk by the bridge except re-applying `chmod 600` to the `.env` file, and the log file if you set `SLACK_CHANNEL_LOG_FILE`.

## Test evidence

End-to-end run on 2026-10-26, Claude Code v2.1.310 (Claude Max, auto mode), started from this folder with
`claude --dangerously-load-development-channels server:slack --allowedTools mcp__slack__reply`.
Brandon (`U01DV0DK1U3`) sent the bot a DM, and the Works button was clicked in Slack.

Startup notice in the session:

```
▎ Channels (experimental) messages from server:slack inject directly in this session · restart without --dangerously-load-development-channels to stop
```

Session transcript:

```
← slack: Bridge test: please reply in this thread with one short sen…
  Called slack
⏺ I sent the reply to your Slack DM thread. It's one sentence with two buttons, Works and Broken. …
← slack: Clicked "Works"
  Called slack
⏺ The bridge test passed both ways. My reply with buttons reached your Slack thread, and your Works click came back to this session. …
```

The `<channel>` tags Claude received, as it printed them back:

```
<channel source="slack" kind="message" channel_id="D0CD1J24316" channel_type="im" thread_ts="1793026563.880269" message_ts="1793026563.880269" user_id="U01DV0DK1U3" user_name="brandon" ts="2026-10-26T14:56:03.880Z">
<channel source="slack" kind="button" action_id="choice_0" action_value="works" channel_id="D0CD1J24316" channel_type="im" thread_ts="1793026563.880269" message_ts="1793026566.824289" user_id="U01DV0DK1U3" user_name="brandon" ts="2026-10-26T14:56:24.888Z">
```

Bridge log (`SLACK_CHANNEL_LOG_FILE`):

```
2026-10-26T14:55:03.165Z socket mode connected
2026-10-26T14:55:03.165Z connected as @claude_code (U0CC1TX1BCM) in Marketo Pros Consulting
2026-10-26T14:56:04.305Z ← brandon in D0CD1J24316 (im): 136 chars
2026-10-26T14:56:06.850Z → reply to D0CD1J24316 thread 1793026563.880269 (1 message, 2 buttons)
2026-10-26T14:56:24.858Z ← brandon clicked "Works" in D0CD1J24316
2026-10-26T14:56:26.081Z → reply to D0CD1J24316 thread 1793026563.880269 (1 message)
2026-10-26T14:57:26.415Z shutting down (SIGINT)
```

Slack permalinks (Brandon's DM with the bot):

| Message | Permalink |
| --- | --- |
| Test DM from Brandon (thread root) | <https://marketo-pros.slack.com/archives/D0CD1J24316/p1793026563880269> |
| Claude's threaded reply with Works / Broken buttons (now "☑️ Works · @brandon") | <https://marketo-pros.slack.com/archives/D0CD1J24316/p1793026566824289?thread_ts=1793026563.880269&cid=D0CD1J24316> |
| Claude's follow-up after the click | <https://marketo-pros.slack.com/archives/D0CD1J24316/p1793026586054009?thread_ts=1793026563.880269&cid=D0CD1J24316> |

After `/exit` no `slack-channel.ts` process remained. Not exercised in this run: a message in a shared channel (only the DM was used), a message from Abi, and the permission relay (the session ran in auto mode with `reply` pre-allowed, so no approval dialog opened).
