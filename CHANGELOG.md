# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.1] - 2026-02-16

### Fixed

- Fixed "unsafe library file" error on Linux/WSL caused by `stat -f` having different semantics across platforms (macOS: file format, Linux: filesystem info), which made ownership validation always fail
- Library file ownership check now also accepts root-owned files (UID 0)
- Improved error diagnostics: the specific check that failed is now included in the error message

## [0.2.0] - 2026-02-14

### Added

- Windows 11 and WSL2 support for Claude Code hook notifications
- New platform detection layer (`plugin/scripts/lib/platform.sh`) using shell best-practice auto detection (`uname -s` + WSL env vars + `/proc` fallback + `OSTYPE` fallback)
- Windows/WSL2 notification backend (`plugin/scripts/lib/windows.sh`) using PowerShell Toast API and `System.Speech` TTS
- New Windows-related config keys:
  - `CC_NOTIFIER_WINDOWS_POWERSHELL_PATH`
  - `CC_NOTIFIER_WINDOWS_APP_ID`
  - `CC_NOTIFIER_WINDOWS_VOICE`
- Smoke tests for platform detection and Windows backend:
  - `plugin/scripts/tests/test_platform.sh`
  - `plugin/scripts/tests/test_windows_backend.sh`

### Changed

- Hook entrypoint now dispatches notification/TTS implementation by detected platform instead of macOS-only guard
- Plugin metadata and README updated from macOS-only wording to macOS/Windows/WSL2 support
- Configuration guides (EN/JA) updated with Windows/WSL2 settings and troubleshooting

### Fixed

- Unsupported platforms no longer fail hard; hooks now log and safely skip notification processing
- macOS notification sound routing now resolves bundled sound names (`info`/`warning`/`complete`/`end`) more reliably and falls back to default sound when a custom sound resource is missing
- macOS direct notifier now waits for notification enqueue completion before exit to reduce intermittent sound delivery issues
- Windows PowerShell backend command detection now supports absolute paths (including paths with spaces) via `CC_NOTIFIER_WINDOWS_POWERSHELL_PATH`

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
