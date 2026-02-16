#!/usr/bin/env bats
# Windows/WSL2 backend integration test (uses a fake PowerShell stub)

setup() {
  load test_helper
  setup_temp_dirs
  unset_cc_notifier_vars

  # Verify required commands
  for cmd in base64 iconv mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || skip "required command not found: $cmd"
  done

  # Create fake PowerShell stub
  export CC_NOTIFIER_TEST_LOG="$TEST_TMP/powershell.log"

  local spaced_dir="$TEST_TMP/powershell with space"
  mkdir -p "$spaced_dir"
  cat > "$spaced_dir/powershell.exe" <<'STUB'
#!/bin/bash
echo "$0 $*" >> "${CC_NOTIFIER_TEST_LOG:?}"
exit 0
STUB
  chmod +x "$spaced_dir/powershell.exe"

  # Set required env vars
  export CC_NOTIFIER_WINDOWS_POWERSHELL_PATH="$spaced_dir/powershell.exe"
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

  # Source libraries
  source "$LIB_DIR/config.sh"
  export CC_NOTIFIER_LANG="en"
  source "$LIB_DIR/i18n.sh"
  source "$LIB_DIR/state.sh"
  source "$LIB_DIR/windows.sh"
}

teardown() {
  teardown_temp_dirs
}

@test "send_notification invokes PowerShell stub" {
  send_notification "Claude Code" "proj" "hello" "info" "notification"

  # Wait for async invocation
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$CC_NOTIFIER_TEST_LOG" ] && break
    sleep 0.1
  done
  [ -f "$CC_NOTIFIER_TEST_LOG" ]
}

@test "send_tts invokes PowerShell stub" {
  send_tts "hello from tts" "notification"

  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$CC_NOTIFIER_TEST_LOG" ] && break
    sleep 0.1
  done
  [ -f "$CC_NOTIFIER_TEST_LOG" ]
}

@test "PowerShell invocations use -EncodedCommand" {
  send_notification "Claude Code" "proj" "hello" "info" "notification"
  send_tts "hello from tts" "notification"

  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$CC_NOTIFIER_TEST_LOG" ] && break
    sleep 0.1
  done
  [ -f "$CC_NOTIFIER_TEST_LOG" ]

  local line_count
  line_count="$(wc -l < "$CC_NOTIFIER_TEST_LOG" | tr -d '[:space:]')"
  [ "$line_count" -ge 2 ]
  grep -q -- "-EncodedCommand" "$CC_NOTIFIER_TEST_LOG"
}
