# Configuration

## Config File

Claude Code hooks run as non-interactive subprocesses. Use a config file instead of relying on shell startup files.

**Default path:** `~/.config/cc-notifier-voice/config`

```bash
mkdir -p ~/.config/cc-notifier-voice
cat > ~/.config/cc-notifier-voice/config << 'EOF2'
CC_NOTIFIER_LANG=en
CC_NOTIFIER_SPEED=175
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
EOF2
```

**Format:** `KEY=VALUE` (one per line, `#` comments supported)

**Custom path:** set `CC_NOTIFIER_CONFIG`

## Priority

`Config file > Environment variable > Default`

## Windows / WSL2 Prerequisites

- Hooks are bash scripts. On Windows 11, run Claude Code from Git Bash/MSYS2/Cygwin (PowerShell-only shells are unsupported).
- Required commands: `bash`, `jq`, `iconv`, `base64`, and `powershell.exe` (or a compatible path via `CC_NOTIFIER_WINDOWS_POWERSHELL_PATH`).

## Environment Variables

### General

| Variable                          | Default | Description                               |
|-----------------------------------|---------|-------------------------------------------|
| `CC_NOTIFIER_ENABLED`             | `true`  | Enable/disable all notifications          |
| `CC_NOTIFIER_TTS_ENABLED`         | `true`  | Enable/disable TTS                        |
| `CC_NOTIFIER_VISUAL_ENABLED`      | `true`  | Enable/disable visual notifications       |
| `CC_NOTIFIER_SOUND_ENABLED`       | `true`  | Enable/disable notification sounds        |
| `CC_NOTIFIER_SPEED`               | `250`   | Speech rate (WPM)                         |
| `CC_NOTIFIER_LANG`                | Auto    | Language (`ja` / `en`)                    |
| `CC_NOTIFIER_VOICE`               | Auto    | Voice name                                |
| `CC_NOTIFIER_TTS_MESSAGE_ENABLED` | `true`  | Read notification message content via TTS |
| `CC_NOTIFIER_WINDOWS_POWERSHELL_PATH` | `powershell.exe` | PowerShell command path for Windows/WSL2 |
| `CC_NOTIFIER_WINDOWS_APP_ID`      | `cc-notifier-voice` | Windows toast App ID |
| `CC_NOTIFIER_WINDOWS_VOICE`       | (empty) | Optional Windows voice name override |

### Per-Event Channel Control

| Variable                    | Default | Description                                          |
|-----------------------------|---------|------------------------------------------------------|
| `CC_NOTIFIER_TTS_EVENTS`    | `all`   | TTS target events (`all` or comma-separated list)    |
| `CC_NOTIFIER_VISUAL_EVENTS` | `all`   | Visual target events (`all` or comma-separated list) |

Available events: `notification`, `permission`, `stop`, `tool-failure`, `completion`

### Rate Limiting and Quiet Hours

| Variable                  | Default | Description                                      |
|---------------------------|---------|--------------------------------------------------|
| `CC_NOTIFIER_COOLDOWN`    | `0`     | Minimum seconds between same-event notifications |
| `CC_NOTIFIER_QUIET_START` | (empty) | Quiet hours start (`HH:MM`)                      |
| `CC_NOTIFIER_QUIET_END`   | (empty) | Quiet hours end (`HH:MM`)                        |

### Slack Integration

| Variable                            | Default        | Description                                     |
|-------------------------------------|----------------|-------------------------------------------------|
| `CC_NOTIFIER_SLACK_ENABLED`         | `false`        | Enable/disable Slack notifications              |
| `CC_NOTIFIER_SLACK_WEBHOOK_URL`     | (empty)        | Slack Incoming Webhook URL                      |
| `CC_NOTIFIER_SLACK_EVENTS`          | `all`          | Slack target events                             |
| `CC_NOTIFIER_OUTBOUND_MESSAGE_MODE` | `summary_only` | Outbound content mode (`summary_only` / `full`) |

Security note: enabling outbound delivery can send notification text to external systems. Configure only trusted endpoints and avoid forwarding sensitive prompts or secrets.

### Generic Webhook

| Variable                            | Default | Description                                                               |
|-------------------------------------|---------|---------------------------------------------------------------------------|
| `CC_NOTIFIER_WEBHOOK_ENABLED`       | `false` | Enable/disable generic webhook                                            |
| `CC_NOTIFIER_WEBHOOK_URL`           | (empty) | HTTPS endpoint                                                            |
| `CC_NOTIFIER_WEBHOOK_EVENTS`        | `all`   | Webhook target events                                                     |
| `CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS` | (empty) | Optional override allowlist (exact or subdomain match)                    |

Security note: webhook destination control is the operator's responsibility. Ensure the receiving service and retention policy meet your organization's security requirements.
By default, only the host of `CC_NOTIFIER_WEBHOOK_URL` is allowed.
Set `CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS` only if you need to explicitly allow additional hosts.

Example:

```bash
CC_NOTIFIER_WEBHOOK_URL=https://hooks.example.com/notify
# Optional (advanced):
CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS=hooks.example.com,webhook.internal.example.com
```

Payload:

```json
{
  "event": "notification",
  "project": "my-project",
  "message": "Notification message text",
  "timestamp": "2026-02-10T17:00:00+00:00"
}
```

## Example Config

```bash
# ~/.config/cc-notifier-voice/config
CC_NOTIFIER_LANG=en
CC_NOTIFIER_VOICE=Samantha
CC_NOTIFIER_SPEED=175
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_VISUAL_ENABLED=true
CC_NOTIFIER_COOLDOWN=5
CC_NOTIFIER_QUIET_START=23:00
CC_NOTIFIER_QUIET_END=07:00
CC_NOTIFIER_SLACK_ENABLED=false
CC_NOTIFIER_WEBHOOK_ENABLED=false
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
# Optional (advanced) when webhook is enabled:
# CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS=hooks.example.com
```

## Troubleshooting

- No notifications (macOS): check notification permission for `CCNotifier`
- No notifications (Windows/WSL2): confirm `bash`, `jq`, `iconv`, `base64`, and `powershell.exe` are available from your shell
- Settings ignored: use config file, not `~/.zshrc`
- No Japanese voice (macOS): install `Kyoko` from macOS voice settings

## Related

- [Main README](../../../README.md)
- [日本語 README](../ja/README.md)
- [設定ガイド (JA)](../ja/configuration.md)
