# 設定

## 設定ファイル

Claude Code の hook は非インタラクティブなサブプロセスで実行されるため、シェル初期化ファイルではなく設定ファイルを使う。

**既定パス:** `~/.config/cc-notifier-voice/config`

```bash
mkdir -p ~/.config/cc-notifier-voice
cat > ~/.config/cc-notifier-voice/config << 'EOF2'
CC_NOTIFIER_LANG=ja
CC_NOTIFIER_SPEED=250
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
EOF2
```

**形式:** `KEY=VALUE`（1行1設定、`#` コメント可）

**カスタムパス:** `CC_NOTIFIER_CONFIG`

## 優先順位

`設定ファイル > 環境変数 > デフォルト`

## 環境変数

### 基本設定

| 変数名                               | デフォルト  | 説明                 |
|-----------------------------------|--------|--------------------|
| `CC_NOTIFIER_ENABLED`             | `true` | 通知全体の有効/無効         |
| `CC_NOTIFIER_TTS_ENABLED`         | `true` | TTS の有効/無効         |
| `CC_NOTIFIER_VISUAL_ENABLED`      | `true` | 視覚通知の有効/無効         |
| `CC_NOTIFIER_SOUND_ENABLED`       | `true` | 通知音の有効/無効          |
| `CC_NOTIFIER_SPEED`               | `250`  | 読み上げ速度 (WPM)       |
| `CC_NOTIFIER_LANG`                | 自動     | 言語 (`ja` / `en`)   |
| `CC_NOTIFIER_VOICE`               | 自動     | 音声名                |
| `CC_NOTIFIER_TTS_MESSAGE_ENABLED` | `true` | 通知メッセージ内容を TTS で読む |

### イベント別チャンネル制御

| 変数名                         | デフォルト | 説明                          |
|-----------------------------|-------|-----------------------------|
| `CC_NOTIFIER_TTS_EVENTS`    | `all` | TTS 対象イベント（`all` またはカンマ区切り） |
| `CC_NOTIFIER_VISUAL_EVENTS` | `all` | 視覚通知対象イベント（`all` またはカンマ区切り） |

指定可能イベント: `notification`, `permission`, `stop`, `tool-failure`, `completion`

### レート制限とおやすみ時間

| 変数名                       | デフォルト | 説明                |
|---------------------------|-------|-------------------|
| `CC_NOTIFIER_COOLDOWN`    | `0`   | 同一イベント通知の最小間隔（秒）  |
| `CC_NOTIFIER_QUIET_START` | (空)   | おやすみ開始時刻（`HH:MM`） |
| `CC_NOTIFIER_QUIET_END`   | (空)   | おやすみ終了時刻（`HH:MM`） |

### Slack 連携

| 変数名                                 | デフォルト          | 説明                                 |
|-------------------------------------|----------------|------------------------------------|
| `CC_NOTIFIER_SLACK_ENABLED`         | `false`        | Slack 通知の有効/無効                     |
| `CC_NOTIFIER_SLACK_WEBHOOK_URL`     | (空)            | Slack Incoming Webhook URL         |
| `CC_NOTIFIER_SLACK_EVENTS`          | `all`          | Slack 通知対象イベント                     |
| `CC_NOTIFIER_OUTBOUND_MESSAGE_MODE` | `summary_only` | 外部送信本文モード（`summary_only` / `full`） |

セキュリティ注意: 外部送信を有効化すると通知本文が外部システムへ送信される可能性があります。信頼できる宛先のみを設定し、機密情報を含む通知は転送しないでください。

### 汎用 Webhook

| 変数名                                 | デフォルト   | 説明                                  |
|-------------------------------------|---------|-------------------------------------|
| `CC_NOTIFIER_WEBHOOK_ENABLED`       | `false` | 汎用 Webhook の有効/無効                   |
| `CC_NOTIFIER_WEBHOOK_URL`           | (空)     | HTTPS エンドポイント                       |
| `CC_NOTIFIER_WEBHOOK_EVENTS`        | `all`   | Webhook 通知対象イベント                    |
| `CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS` | (空)     | 任意の許可ホスト上書き（カンマ区切り、完全一致またはサブドメイン一致） |

セキュリティ注意: Webhook 宛先の選定と運用責任は設定者にあります。受信先サービスの保護レベルとデータ保持ポリシーを事前に確認してください。
既定では `CC_NOTIFIER_WEBHOOK_URL` のホストのみ送信許可されます。
追加ホストを明示的に許可したい場合のみ `CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS` を設定してください。

例:

```bash
CC_NOTIFIER_WEBHOOK_URL=https://hooks.example.com/notify
# 任意（上級者向け）
CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS=hooks.example.com,webhook.internal.example.com
```

ペイロード:

```json
{
  "event": "notification",
  "project": "my-project",
  "message": "通知メッセージ",
  "timestamp": "2026-02-10T17:00:00+00:00"
}
```

## 設定例

```bash
# ~/.config/cc-notifier-voice/config
CC_NOTIFIER_LANG=ja
CC_NOTIFIER_VOICE=Kyoko
CC_NOTIFIER_SPEED=250
CC_NOTIFIER_TTS_ENABLED=true
CC_NOTIFIER_VISUAL_ENABLED=true
CC_NOTIFIER_COOLDOWN=5
CC_NOTIFIER_QUIET_START=23:00
CC_NOTIFIER_QUIET_END=07:00
CC_NOTIFIER_SLACK_ENABLED=false
CC_NOTIFIER_WEBHOOK_ENABLED=false
CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only
# 任意（上級者向け）:
# CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS=hooks.example.com
```

## トラブルシューティング

- 通知が出ない: macOS の `CCNotifier` 通知許可を確認
- 設定が反映されない: `~/.zshrc` ではなく設定ファイルを利用
- 日本語音声が出ない: macOS で `Kyoko` を追加

## 関連ドキュメント

- [README](./README.md)
