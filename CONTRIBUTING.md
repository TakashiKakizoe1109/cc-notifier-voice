# Contributing to cc-notifier-voice

Thank you for your interest in contributing to cc-notifier-voice.

## Development Setup

1. Clone the repository:

```bash
git clone https://github.com/TakashiKakizoe1109/cc-notifier-voice.git
cd cc-notifier-voice
```

2. Verify the hook script runs without errors:

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)/plugin" CLAUDE_PROJECT_DIR="$(pwd)" \
  ./plugin/scripts/cc-notifier.sh notification < /dev/null
echo "Exit code: $?"
```

Exit code should be `0`.

## Project Structure

```
plugin/
  .claude-plugin/   Plugin metadata
  hooks/            Hook definitions (hooks.json)
  macos/            Native app bundle (CCNotifier.app, Swift source, build script)
  scripts/
    cc-notifier.sh  Main dispatcher
    lib/
      config.sh     Config file loader, env defaults, validation
      i18n.sh       Language messages (ja/en)
      state.sh      SubAgent state management, session locking
      platform.sh   Platform detection (macOS / WSL2 / Windows)
      macos.sh      macOS notification (via CCNotifier.app) + TTS
      windows.sh    Windows/WSL2 notification (PowerShell toast) + TTS
      slack.sh      Slack webhook integration
tests/              Bats test suite
docs/
  i18n/en/          English documentation
  i18n/ja/          Japanese documentation
```

Note: `plugin/macos/` contains the native macOS app bundle only.
Windows/WSL2 uses PowerShell directly and does not require a separate native app directory.

## Code Style

- Shell scripts: bash, 2-space indent
- No emojis in any committed files
- Commit messages: [Conventional Commits](https://www.conventionalcommits.org/) format (`fix:`, `feat:`, `chore:`, etc.)

## Before Submitting a PR

1. **Syntax check** all modified shell scripts:

```bash
bash -n plugin/scripts/cc-notifier.sh
bash -n plugin/scripts/lib/*.sh
```

2. **Run tests** (requires [bats-core](https://github.com/bats-core/bats-core): `brew install bats-core`):

```bash
bats tests/
```

3. **Documentation**: if you change user-facing behavior, update both EN and JA docs in the same commit.

4. **Version**: do not bump version numbers in PRs. Version updates are handled during release.

## Security

- No `eval` or unquoted command expansion for user/config input
- Arguments to executables must be passed as arrays
- See `CLAUDE.md` for full security guardrails

## Reporting Bugs

Use the [Bug Report](https://github.com/TakashiKakizoe1109/cc-notifier-voice/issues/new?template=bug_report.yml) issue template.

## Reporting Security Vulnerabilities

See [SECURITY.md](SECURITY.md).
