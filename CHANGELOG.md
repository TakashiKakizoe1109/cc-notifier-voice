# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-02-10

Initial release.

### Added

- macOS banner notifications via CCNotifier.app
- Text-to-speech with language-based voice auto-selection (`say` command)
- 7 hook events: Notification, PermissionRequest, Stop, SessionEnd, PostToolUseFailure, SubagentStart, SubagentStop
- SubAgent-aware stop suppression (skip stop notification while SubAgents are running)
- Distinct notification sounds per event type (bundled, Pixabay-licensed)
- Per-event channel filtering (`CC_NOTIFIER_TTS_EVENTS`, `_VISUAL_EVENTS`, `_SLACK_EVENTS`, `_WEBHOOK_EVENTS`)
- Dedicated config file (`~/.config/cc-notifier-voice/config`) with config file > env var > default priority
- Notification cooldown / rate limiting (`CC_NOTIFIER_COOLDOWN`)
- Quiet hours (`CC_NOTIFIER_QUIET_START` / `CC_NOTIFIER_QUIET_END`) -- suppresses TTS and sounds
- Configurable speech rate (`CC_NOTIFIER_SPEED`)
- TTS message readout toggle (`CC_NOTIFIER_TTS_MESSAGE_ENABLED`)
- Slack Incoming Webhook integration (`CC_NOTIFIER_SLACK_WEBHOOK_URL`)
- Generic HTTPS webhook with host allowlist (`CC_NOTIFIER_WEBHOOK_URL`, `CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS`)
- Japanese and English message support with system locale auto-detection
