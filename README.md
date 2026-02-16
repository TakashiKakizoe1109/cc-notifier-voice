# cc-notifier-voice

[English](README.md) | [日本語](docs/i18n/ja/README.md)

Desktop notification plugin for Claude Code with voice announcements (TTS) on macOS, Windows, and WSL2.

![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%2011%20%7C%20WSL2-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## What It Does

- Shows desktop notifications for Claude Code hook events
- Reads messages aloud with native TTS
- Distinct notification sounds per event type
- Optionally sends event summaries to Slack or generic webhook endpoints
- Suppresses noisy stop alerts while SubAgents are running

## Security Note

- Enabling Slack/Webhook delivery may transmit notification text to external systems.
- Endpoint selection and data handling responsibility belong to the user/operator.
- Hook commands use the official Claude plugin pattern with `${CLAUDE_PLUGIN_ROOT}` and fixed event names.
- `CCNotifier.app` is currently distributed without a Developer ID signature. To reduce tampering risk, the plugin checks that the app file exactly matches a pre-registered fingerprint (SHA256) before launching it.
- Keep Slack/Webhook disabled unless required, then enable only for trusted endpoints.

Recommended safe baseline:

```bash
CC_NOTIFIER_SLACK_ENABLED=false
CC_NOTIFIER_WEBHOOK_ENABLED=false
CC_NOTIFIER_REDACT_SENSITIVE=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
```

- [More Configuration guide](docs/i18n/en/configuration.md)

## Event Coverage

| Event              | Visual | TTS |
|--------------------|--------|-----|
| Notification       | Yes    | Yes |
| PermissionRequest  | Yes    | Yes |
| Stop               | Yes    | Yes |
| PostToolUseFailure | Yes    | Yes |
| SessionEnd         | Yes    | Yes |

## Requirements

- Claude Code
- One of:
  - macOS 11.0 or later
  - Windows 11 with POSIX shell runtime (`bash` via Git Bash/MSYS2/Cygwin) and tools: `jq`, `iconv`, `base64`, `powershell.exe`
  - WSL2 on Windows 11 with tools: `bash`, `jq`, `iconv`, `base64` and `powershell.exe` interop available

PowerShell-only native execution is not supported. Hooks execute via `plugin/scripts/cc-notifier.sh` (`#!/bin/bash`).

## Installation

In Claude Code, run the following commands:

```
/plugin marketplace add TakashiKakizoe1109/cc-notifier-voice
/plugin install cc-notifier-voice
```

Restart Claude Code after installation.

## Quick Start

1. Allow notification permission on first run.
2. Create a config file:

```bash
mkdir -p ~/.config/cc-notifier-voice
cat > ~/.config/cc-notifier-voice/config << 'EOF2'
CC_NOTIFIER_LANG=en
CC_NOTIFIER_SPEED=175
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
EOF2
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

[MIT](LICENSE)
