# cc-notifier-voice

[English](../../../README.md) | [日本語](README.md)

Claude Code のイベントを、macOS の通知と音声読み上げ (TTS) で知らせるプラグイン。

![macOS](https://img.shields.io/badge/platform-macOS%2011.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## できること

- Claude Code の各イベントでデスクトップ通知を表示
- macOS TTS で読み上げ
- イベントタイプごとに異なる通知音
- オプションで Slack / 汎用 Webhook 通知
- SubAgent 実行中は Stop 通知を抑制して誤通知を防止

## セキュリティ注意

- Slack / Webhook 送信を有効化すると、通知本文が外部システムへ送信される可能性があります。
- 宛先の選定と送信データの取り扱い責任は、設定者（運用者）にあります。
- Hook コマンドは、Claude プラグイン公式パターン（`${CLAUDE_PLUGIN_ROOT}` + 固定イベント名）で実行されます。
- `CCNotifier.app` は現在、Developer ID 署名なしで配布されています。改ざんリスクを下げるため、起動前に「事前登録したファイル指紋（SHA256）」と完全一致するかを確認してから実行します。
- Slack / Webhook は必要時のみ有効化し、信頼できる宛先に限定してください。

推奨の安全な初期設定:

```bash
CC_NOTIFIER_SLACK_ENABLED=false
CC_NOTIFIER_WEBHOOK_ENABLED=false
CC_NOTIFIER_REDACT_SENSITIVE=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
```

- [設定ガイド (JA)](configuration.md)

## 対応イベント

| イベント               | 視覚通知 | TTS |
|--------------------|------|-----|
| Notification       | あり   | あり  |
| PermissionRequest  | あり   | あり  |
| Stop               | あり   | あり  |
| PostToolUseFailure | あり   | あり  |
| SessionEnd         | あり   | あり  |

## 動作環境

- macOS 11.0 以降
- Claude Code

## インストール

Claude Code 内で以下のコマンドを実行:

```
/plugin marketplace add TakashiKakizoe1109/cc-notifier-voice
/plugin install cc-notifier-voice
```

インストール後、Claude Code を再起動してください。

## クイックスタート

1. 初回実行時に通知権限を許可する
2. 設定ファイルを作成する

```bash
mkdir -p ~/.config/cc-notifier-voice
cat > ~/.config/cc-notifier-voice/config << 'EOF2'
CC_NOTIFIER_LANG=ja
CC_NOTIFIER_SPEED=250
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
EOF2
```

## ライセンス

[MIT](../../../LICENSE)
