#!/bin/bash
# macOS implementation (CCNotifier direct mode + say TTS)

# ============================================================================
# Default voice based on language
# ============================================================================

if [ -z "$CC_NOTIFIER_VOICE" ]; then
  case "$CC_NOTIFIER_LANG" in
    ja) CC_NOTIFIER_VOICE="Kyoko" ;;
    *)  CC_NOTIFIER_VOICE="Samantha" ;;
  esac
fi

# Sanitize voice parameter: block option injection and invalid characters
case "$CC_NOTIFIER_VOICE" in
  -*) case "$CC_NOTIFIER_LANG" in ja) CC_NOTIFIER_VOICE="Kyoko" ;; *) CC_NOTIFIER_VOICE="Samantha" ;; esac ;;
esac
CC_NOTIFIER_VOICE=$(printf '%s' "$CC_NOTIFIER_VOICE" | tr -cd 'A-Za-z0-9 _()-')
[ -z "$CC_NOTIFIER_VOICE" ] && { case "$CC_NOTIFIER_LANG" in ja) CC_NOTIFIER_VOICE="Kyoko" ;; *) CC_NOTIFIER_VOICE="Samantha" ;; esac; }

# TTS PID tracking
_TTS_PID_FILE="$STATE_DIR/.tts-pid"
_CC_NOTIFIER_BIN_VERIFIED=""

# ============================================================================
# Event filter helpers
# ============================================================================

_is_visual_event_enabled() {
  local event="$1"
  [ "$CC_NOTIFIER_VISUAL_EVENTS" = "all" ] && return 0

  local IFS=','
  local e
  for e in $CC_NOTIFIER_VISUAL_EVENTS; do
    e="${e## }"; e="${e%% }"
    [ "$e" = "$event" ] && return 0
  done
  return 1
}

_is_tts_event_enabled() {
  local event="$1"
  [ "$CC_NOTIFIER_TTS_EVENTS" = "all" ] && return 0

  local IFS=','
  local e
  for e in $CC_NOTIFIER_TTS_EVENTS; do
    e="${e## }"; e="${e%% }"
    [ "$e" = "$event" ] && return 0
  done
  return 1
}

# ============================================================================
# Notification function (direct mode -- stateless, no daemon)
# ============================================================================

_sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" 2>/dev/null | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" 2>/dev/null | awk '{print $1}'
    return 0
  fi
  return 1
}


_is_bundle_dir_safe() {
  local path="$1"
  [ -n "$path" ] || return 1
  [ -d "$path" ] || return 1
  [ -L "$path" ] && return 1
  local owner mode
  owner=$(stat -f '%u' "$path" 2>/dev/null) || return 1
  [ "$owner" = "$(id -u)" ] || return 1
  mode=$(stat -f '%Lp' "$path" 2>/dev/null) || return 1
  _is_group_or_other_writable_mode "$mode" && return 1
  return 0
}

_is_file_safe() {
  local path="$1"
  [ -n "$path" ] || return 1
  [ -f "$path" ] || return 1
  [ -L "$path" ] && return 1
  local owner mode
  owner=$(stat -f '%u' "$path" 2>/dev/null) || return 1
  [ "$owner" = "$(id -u)" ] || return 1
  mode=$(stat -f '%Lp' "$path" 2>/dev/null) || return 1
  _is_group_or_other_writable_mode "$mode" && return 1
  return 0
}

_verify_codesign_bundle() {
  local app_dir="$1"
  command -v codesign >/dev/null 2>&1 || {
    echo "cc-notifier-voice: codesign not found, refusing to execute CCNotifier" >&2
    return 1
  }
  codesign --verify --deep --strict "$app_dir" >/dev/null 2>&1 || {
    echo "cc-notifier-voice: CCNotifier code signature verification failed" >&2
    return 1
  }
  if [ -n "$CC_NOTIFIER_CODESIGN_TEAM_ID" ]; then
    local actual_team
    actual_team=$(codesign -dv --verbose=4 "$app_dir" 2>&1 | awk -F= '/^TeamIdentifier=/{print $2; exit}')
    if [ "$actual_team" != "$CC_NOTIFIER_CODESIGN_TEAM_ID" ]; then
      echo "cc-notifier-voice: CCNotifier Team ID mismatch, refusing to execute" >&2
      return 1
    fi
  fi
  return 0
}

_verify_ccnotifier_binary() {
  local ccnotifier="$1"

  [ "$_CC_NOTIFIER_BIN_VERIFIED" = "$ccnotifier" ] && return 0

  _is_file_safe "$ccnotifier" || {
    echo "cc-notifier-voice: CCNotifier binary is not safe to execute" >&2
    return 1
  }

  local app_dir
  app_dir=$(dirname "$(dirname "$(dirname "$ccnotifier")")")
  _is_bundle_dir_safe "$app_dir" || {
    echo "cc-notifier-voice: CCNotifier app bundle directory is unsafe" >&2
    return 1
  }
  _is_bundle_dir_safe "${app_dir}/Contents" || {
    echo "cc-notifier-voice: CCNotifier app bundle Contents directory is unsafe" >&2
    return 1
  }
  _is_bundle_dir_safe "${app_dir}/Contents/MacOS" || {
    echo "cc-notifier-voice: CCNotifier app bundle MacOS directory is unsafe" >&2
    return 1
  }
  _is_file_safe "${app_dir}/Contents/Info.plist" || {
    echo "cc-notifier-voice: CCNotifier bundle metadata is unsafe" >&2
    return 1
  }
  _verify_codesign_bundle "$app_dir" || return 1

  if [ -n "$CC_NOTIFIER_BINARY_SHA256" ]; then
    local actual_sha normalized_expected
    actual_sha=$(_sha256_file "$ccnotifier") || {
      echo "cc-notifier-voice: failed to compute CCNotifier hash" >&2
      return 1
    }
    normalized_expected=$(printf '%s' "$CC_NOTIFIER_BINARY_SHA256" | tr '[:upper:]' '[:lower:]')
    if [ "$actual_sha" != "$normalized_expected" ]; then
      echo "cc-notifier-voice: CCNotifier hash mismatch, refusing to execute" >&2
      return 1
    fi
  fi

  _CC_NOTIFIER_BIN_VERIFIED="$ccnotifier"
  return 0
}

send_notification() {
  local title="$1"
  local subtitle="$2"
  local message="$3"
  local sound="$4"
  local event="$5"

  is_visual_enabled || return 0
  [ -n "$event" ] && { _is_visual_event_enabled "$event" || return 0; }

  local ccnotifier="${CLAUDE_PLUGIN_ROOT}/macos/CCNotifier.app/Contents/MacOS/CCNotifier"
  [ -x "$ccnotifier" ] || return 0
  _verify_ccnotifier_binary "$ccnotifier" || return 0

  # Build argument array
  local args=(-title "$title" -subtitle "$subtitle" -message "$message")

  if is_sound_enabled && [ -n "$sound" ]; then
    args+=(-sound "$sound")
  fi

  args+=(-group "claude-code-${subtitle}")

  # Fire-and-forget: direct mode runs ~0.1s in background
  "$ccnotifier" "${args[@]}" &
}

# ============================================================================
# Text-to-Speech function (say command, last-wins)
# ============================================================================

send_tts() {
  local message="$1"
  local event="$2"

  is_tts_enabled || return 0
  [ -n "$event" ] && { _is_tts_event_enabled "$event" || return 0; }
  _ensure_state_dir || return 0

  # Cancel previous TTS (last-wins)
  _cancel_tts

  say -v "$CC_NOTIFIER_VOICE" -r "$CC_NOTIFIER_SPEED" -- "$message" &
  [ -L "$_TTS_PID_FILE" ] && { rm -f "$_TTS_PID_FILE"; return 0; }
  local tmp_pid
  tmp_pid=$(mktemp "${STATE_DIR}/.tts-pid.XXXXXX" 2>/dev/null) || return 0
  echo $! > "$tmp_pid"
  mv -f "$tmp_pid" "$_TTS_PID_FILE" 2>/dev/null || { rm -f "$tmp_pid"; return 0; }
}

_cancel_tts() {
  _ensure_state_dir_safe || return 0
  [ -f "$_TTS_PID_FILE" ] || return 0
  [ -L "$_TTS_PID_FILE" ] && { rm -f "$_TTS_PID_FILE"; return 0; }
  local pid
  pid=$(cat "$_TTS_PID_FILE" 2>/dev/null) || return 0
  case "$pid" in
    ''|*[!0-9]*) return 0 ;;
  esac

  # Avoid killing unrelated processes when PID has been recycled.
  local cmd
  cmd=$(ps -p "$pid" -o comm= 2>/dev/null | awk 'NR==1{print $1}')
  case "$cmd" in
    say|*/say) ;;
    *) rm -f "$_TTS_PID_FILE"; return 0 ;;
  esac

  kill "$pid" 2>/dev/null
  rm -f "$_TTS_PID_FILE"
}
