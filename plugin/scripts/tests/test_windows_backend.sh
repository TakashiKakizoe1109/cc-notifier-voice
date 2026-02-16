#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

for cmd in base64 iconv mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command not found for test: $cmd"
done

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cc-notifier-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="$TMP_ROOT/home"
mkdir -p "$HOME"
export CC_NOTIFIER_TEST_LOG="$TMP_ROOT/powershell.log"

FAKE_POWERSHELL="$TMP_ROOT/powershell.exe"
cat > "$FAKE_POWERSHELL" <<'EOF'
#!/bin/bash
echo "$0 $*" >> "${CC_NOTIFIER_TEST_LOG:?}"
exit 0
EOF
chmod +x "$FAKE_POWERSHELL"

FAKE_POWERSHELL_SPACED_DIR="$TMP_ROOT/powershell with space"
mkdir -p "$FAKE_POWERSHELL_SPACED_DIR"
FAKE_POWERSHELL_SPACED="$FAKE_POWERSHELL_SPACED_DIR/powershell.exe"
cp "$FAKE_POWERSHELL" "$FAKE_POWERSHELL_SPACED"
chmod +x "$FAKE_POWERSHELL_SPACED"

export CC_NOTIFIER_WINDOWS_POWERSHELL_PATH="$FAKE_POWERSHELL_SPACED"
export CC_NOTIFIER_ENABLED=true
export CC_NOTIFIER_VISUAL_ENABLED=true
export CC_NOTIFIER_TTS_ENABLED=true
export CC_NOTIFIER_SOUND_ENABLED=true
export CC_NOTIFIER_VISUAL_EVENTS=all
export CC_NOTIFIER_TTS_EVENTS=all
export CC_NOTIFIER_SPEED=250
export CC_NOTIFIER_WINDOWS_APP_ID=cc-notifier-voice-test
export CC_NOTIFIER_VOICE=""
export CC_NOTIFIER_WINDOWS_VOICE=""

# shellcheck disable=SC1090
source "$LIB_DIR/config.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/i18n.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/state.sh"
# shellcheck disable=SC1090
source "$LIB_DIR/windows.sh"

send_notification "Claude Code" "proj" "hello" "info" "notification"
send_tts "hello from tts" "notification"

for _ in 1 2 3 4 5; do
  [ -f "$CC_NOTIFIER_TEST_LOG" ] && break
  sleep 0.1
done
[ -f "$CC_NOTIFIER_TEST_LOG" ] || fail "powershell stub was not invoked"

line_count="$(wc -l < "$CC_NOTIFIER_TEST_LOG" | tr -d '[:space:]')"
case "$line_count" in
  ''|*[!0-9]*) fail "invalid log line count: $line_count" ;;
esac
[ "$line_count" -ge 2 ] || fail "expected at least 2 powershell invocations, got $line_count"

grep -q -- "-EncodedCommand" "$CC_NOTIFIER_TEST_LOG" || fail "missing -EncodedCommand in powershell invocation"

echo "PASS: windows backend smoke tests"
