# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | Yes       |
| < 0.2.0 | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in cc-notifier-voice, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please use [GitHub Private Vulnerability Reporting](https://github.com/TakashiKakizoe1109/cc-notifier-voice/security/advisories/new) to submit your report.

### What to include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact

### Response timeline

- Acknowledgement: within 72 hours
- Initial assessment: within 1 week
- Fix or mitigation: best effort, depending on severity

### Scope

The following are in scope:

- Command injection or arbitrary code execution via hook scripts
- Config file parsing bypasses (eval injection, path traversal)
- Unauthorized file read/write/delete
- Credential or secret exposure in logs or arguments
- Binary verification bypass (CCNotifier.app hash/signature)

The following are out of scope:

- Risks from user-configured Slack/Webhook endpoints (accepted operational risk)
- macOS notification permission settings
- Issues requiring physical access to the machine
