#!/bin/bash
# Configuration loader, environment defaults, and feature flags

# ============================================================================
# Config file support
# Priority: config file > env var > default
# ============================================================================

_CC_CONFIG_FILE="${CC_NOTIFIER_CONFIG:-$HOME/.config/cc-notifier-voice/config}"
_CC_NOTIFIER_DEFAULT_BINARY_SHA256="1acaab63a198bdc8a04a8db9ee84770ad7ddc125998ebceda5bff1a69d06de9b"

_cc_cfg_stat_owner() {
  stat -f '%u' "$1" 2>/dev/null || stat -c '%u' "$1" 2>/dev/null
}

_cc_cfg_stat_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

_is_group_or_other_writable_mode() {
  local mode="$1"
  case "$mode" in
    ''|*[!0-7]*) return 0 ;;
  esac
  local perm="${mode#${mode%???}}"
  [ ${#perm} -eq 3 ] || return 0
  [ $((8#$perm & 8#022)) -ne 0 ]
}

_cc_config_safe=false
if [ -f "$_CC_CONFIG_FILE" ]; then
  if [ -L "$_CC_CONFIG_FILE" ]; then
    echo "cc-notifier-voice: config file is a symlink, skipping" >&2
    _cc_config_safe=false
  else
  # Verify ownership and permissions before loading
  _cc_file_owner=$(_cc_cfg_stat_owner "$_CC_CONFIG_FILE")
  _cc_file_mode=$(_cc_cfg_stat_mode "$_CC_CONFIG_FILE")
  _cc_config_safe=true
  if [ "$_cc_file_owner" != "$(id -u)" ]; then
    echo "cc-notifier-voice: config file not owned by current user, skipping" >&2
    _cc_config_safe=false
  fi
  if _is_group_or_other_writable_mode "$_cc_file_mode"; then
      echo "cc-notifier-voice: config file is group/other-writable, skipping" >&2
      _cc_config_safe=false
  fi
  if [ "$_cc_config_safe" = "true" ]; then
    _cc_parent_dir=$(dirname "$_CC_CONFIG_FILE")
    _cc_parent_owner=$(_cc_cfg_stat_owner "$_cc_parent_dir")
    _cc_parent_mode=$(_cc_cfg_stat_mode "$_cc_parent_dir")
    if [ "$_cc_parent_owner" != "$(id -u)" ]; then
      echo "cc-notifier-voice: config parent dir not owned by current user, skipping" >&2
      _cc_config_safe=false
    fi
    if _is_group_or_other_writable_mode "$_cc_parent_mode"; then
        echo "cc-notifier-voice: config parent dir is group/other-writable, skipping" >&2
        _cc_config_safe=false
    fi
  fi
  unset _cc_file_owner _cc_file_mode
  unset _cc_parent_dir _cc_parent_owner _cc_parent_mode
  fi
fi

if [ "$_cc_config_safe" = "true" ]; then
  while IFS= read -r _line || [ -n "$_line" ]; do
    _line="${_line## }"; _line="${_line%% }"
    case "$_line" in '#'*|'') continue ;; esac
    _key="${_line%%=*}"; _val="${_line#*=}"
    # Strip surrounding quotes
    case "$_val" in \"*\") _val="${_val#\"}"; _val="${_val%\"}" ;; esac
    case "$_val" in \'*\') _val="${_val#\'}"; _val="${_val%\'}" ;; esac
    # Whitelist: config file wins over env vars (no eval)
    case "$_key" in
      CC_NOTIFIER_ENABLED)            CC_NOTIFIER_ENABLED="$_val" ;;
      CC_NOTIFIER_TTS_ENABLED)        CC_NOTIFIER_TTS_ENABLED="$_val" ;;
      CC_NOTIFIER_VISUAL_ENABLED)     CC_NOTIFIER_VISUAL_ENABLED="$_val" ;;
      CC_NOTIFIER_SOUND_ENABLED)      CC_NOTIFIER_SOUND_ENABLED="$_val" ;;
      CC_NOTIFIER_SPEED)              CC_NOTIFIER_SPEED="$_val" ;;
      CC_NOTIFIER_LANG)               CC_NOTIFIER_LANG="$_val" ;;
      CC_NOTIFIER_VOICE)              CC_NOTIFIER_VOICE="$_val" ;;
      CC_NOTIFIER_TTS_MESSAGE_ENABLED) CC_NOTIFIER_TTS_MESSAGE_ENABLED="$_val" ;;
      CC_NOTIFIER_WINDOWS_POWERSHELL_PATH) CC_NOTIFIER_WINDOWS_POWERSHELL_PATH="$_val" ;;
      CC_NOTIFIER_WINDOWS_APP_ID)     CC_NOTIFIER_WINDOWS_APP_ID="$_val" ;;
      CC_NOTIFIER_WINDOWS_VOICE)      CC_NOTIFIER_WINDOWS_VOICE="$_val" ;;
      CC_NOTIFIER_TTS_EVENTS)         CC_NOTIFIER_TTS_EVENTS="$_val" ;;
      CC_NOTIFIER_VISUAL_EVENTS)      CC_NOTIFIER_VISUAL_EVENTS="$_val" ;;
      CC_NOTIFIER_COOLDOWN)           CC_NOTIFIER_COOLDOWN="$_val" ;;
      CC_NOTIFIER_QUIET_START)        CC_NOTIFIER_QUIET_START="$_val" ;;
      CC_NOTIFIER_QUIET_END)          CC_NOTIFIER_QUIET_END="$_val" ;;
      CC_NOTIFIER_SLACK_ENABLED)      CC_NOTIFIER_SLACK_ENABLED="$_val" ;;
      CC_NOTIFIER_SLACK_WEBHOOK_URL)  CC_NOTIFIER_SLACK_WEBHOOK_URL="$_val" ;;
      CC_NOTIFIER_SLACK_EVENTS)       CC_NOTIFIER_SLACK_EVENTS="$_val" ;;
      CC_NOTIFIER_WEBHOOK_ENABLED)    CC_NOTIFIER_WEBHOOK_ENABLED="$_val" ;;
      CC_NOTIFIER_WEBHOOK_URL)        CC_NOTIFIER_WEBHOOK_URL="$_val" ;;
      CC_NOTIFIER_WEBHOOK_EVENTS)     CC_NOTIFIER_WEBHOOK_EVENTS="$_val" ;;
      CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS) CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS="$_val" ;;
      CC_NOTIFIER_MAX_STDIN_BYTES)    CC_NOTIFIER_MAX_STDIN_BYTES="$_val" ;;
      CC_NOTIFIER_BINARY_SHA256)      CC_NOTIFIER_BINARY_SHA256="$_val" ;;
      CC_NOTIFIER_REDACT_SENSITIVE)   CC_NOTIFIER_REDACT_SENSITIVE="$_val" ;;
      CC_NOTIFIER_OUTBOUND_MESSAGE_MODE) CC_NOTIFIER_OUTBOUND_MESSAGE_MODE="$_val" ;;
      CC_NOTIFIER_CODESIGN_TEAM_ID)   CC_NOTIFIER_CODESIGN_TEAM_ID="$_val" ;;
    esac
  done < "$_CC_CONFIG_FILE"
  unset _line _key _val
fi
unset _cc_config_safe

# ============================================================================
# Environment variable defaults
# ============================================================================

: "${CC_NOTIFIER_ENABLED:=true}"
: "${CC_NOTIFIER_TTS_ENABLED:=true}"
: "${CC_NOTIFIER_VISUAL_ENABLED:=true}"
: "${CC_NOTIFIER_SOUND_ENABLED:=true}"
: "${CC_NOTIFIER_SPEED:=250}"
: "${CC_NOTIFIER_TTS_MESSAGE_ENABLED:=true}"
: "${CC_NOTIFIER_WINDOWS_POWERSHELL_PATH:=powershell.exe}"
: "${CC_NOTIFIER_WINDOWS_APP_ID:=cc-notifier-voice}"
: "${CC_NOTIFIER_WINDOWS_VOICE:=}"
: "${CC_NOTIFIER_TTS_EVENTS:=all}"
: "${CC_NOTIFIER_VISUAL_EVENTS:=all}"
: "${CC_NOTIFIER_COOLDOWN:=0}"
: "${CC_NOTIFIER_QUIET_START:=}"
: "${CC_NOTIFIER_QUIET_END:=}"
: "${CC_NOTIFIER_SLACK_ENABLED:=false}"
: "${CC_NOTIFIER_SLACK_WEBHOOK_URL:=}"
: "${CC_NOTIFIER_SLACK_EVENTS:=all}"
: "${CC_NOTIFIER_WEBHOOK_ENABLED:=false}"
: "${CC_NOTIFIER_WEBHOOK_URL:=}"
: "${CC_NOTIFIER_WEBHOOK_EVENTS:=all}"
: "${CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS:=}"
: "${CC_NOTIFIER_MAX_STDIN_BYTES:=16384}"
: "${CC_NOTIFIER_BINARY_SHA256:=$_CC_NOTIFIER_DEFAULT_BINARY_SHA256}"
: "${CC_NOTIFIER_REDACT_SENSITIVE:=true}"
: "${CC_NOTIFIER_OUTBOUND_MESSAGE_MODE:=summary_only}"
: "${CC_NOTIFIER_CODESIGN_TEAM_ID:=}"

# Language: auto-detect from system locale if not set
if [ -z "${CC_NOTIFIER_LANG+x}" ]; then
  case "${LANG:-}" in
    ja*) CC_NOTIFIER_LANG="ja" ;;
    *)   CC_NOTIFIER_LANG="en" ;;
  esac
fi

# Validate: speed must be numeric
case "$CC_NOTIFIER_SPEED" in
  ''|*[!0-9]*) CC_NOTIFIER_SPEED=250 ;;
esac

# Validate: powershell command path cannot be empty
[ -z "$CC_NOTIFIER_WINDOWS_POWERSHELL_PATH" ] && CC_NOTIFIER_WINDOWS_POWERSHELL_PATH="powershell.exe"

# Validate: app id cannot be empty
[ -z "$CC_NOTIFIER_WINDOWS_APP_ID" ] && CC_NOTIFIER_WINDOWS_APP_ID="cc-notifier-voice"

# Validate: cooldown must be numeric
case "$CC_NOTIFIER_COOLDOWN" in
  ''|*[!0-9]*) CC_NOTIFIER_COOLDOWN=0 ;;
esac

# Validate: stdin byte limit must be numeric and sane (1KiB-1MiB)
case "$CC_NOTIFIER_MAX_STDIN_BYTES" in
  ''|*[!0-9]*) CC_NOTIFIER_MAX_STDIN_BYTES=16384 ;;
esac
if [ "$CC_NOTIFIER_MAX_STDIN_BYTES" -lt 1024 ] 2>/dev/null; then
  CC_NOTIFIER_MAX_STDIN_BYTES=1024
fi
if [ "$CC_NOTIFIER_MAX_STDIN_BYTES" -gt 1048576 ] 2>/dev/null; then
  CC_NOTIFIER_MAX_STDIN_BYTES=1048576
fi

# Validate: sensitive redaction flag
case "$CC_NOTIFIER_REDACT_SENSITIVE" in
  true|false) ;;
  *) CC_NOTIFIER_REDACT_SENSITIVE=true ;;
esac

# Validate: outbound message mode
case "$CC_NOTIFIER_OUTBOUND_MESSAGE_MODE" in
  full|summary_only) ;;
  *) CC_NOTIFIER_OUTBOUND_MESSAGE_MODE=summary_only ;;
esac

# Validate: optional Team ID pin (Apple Developer Team ID: 10 uppercase alnum)
if [ -n "$CC_NOTIFIER_CODESIGN_TEAM_ID" ]; then
  CC_NOTIFIER_CODESIGN_TEAM_ID=$(printf '%s' "$CC_NOTIFIER_CODESIGN_TEAM_ID" | tr '[:lower:]' '[:upper:]')
  if ! printf '%s' "$CC_NOTIFIER_CODESIGN_TEAM_ID" | grep -Eq '^[A-Z0-9]{10}$'; then
    echo "cc-notifier-voice: invalid CC_NOTIFIER_CODESIGN_TEAM_ID, disabling Team ID pin" >&2
    CC_NOTIFIER_CODESIGN_TEAM_ID=""
  fi
fi

# Validate: pinned hash must be 64 lowercase/uppercase hex chars
if [ -n "$CC_NOTIFIER_BINARY_SHA256" ]; then
  CC_NOTIFIER_BINARY_SHA256=$(printf '%s' "$CC_NOTIFIER_BINARY_SHA256" | tr '[:upper:]' '[:lower:]')
  if ! printf '%s' "$CC_NOTIFIER_BINARY_SHA256" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "cc-notifier-voice: invalid CC_NOTIFIER_BINARY_SHA256, falling back to default pinned hash" >&2
    CC_NOTIFIER_BINARY_SHA256="$_CC_NOTIFIER_DEFAULT_BINARY_SHA256"
  fi
fi

# ============================================================================
# Sound names per event (fixed, bundled Pixabay-licensed sounds)
# ============================================================================

CC_NOTIFIER_SOUND_NOTIFICATION="info"
CC_NOTIFIER_SOUND_PERMISSION="warning"
CC_NOTIFIER_SOUND_STOP="complete"
CC_NOTIFIER_SOUND_TOOL_FAILURE="warning"
CC_NOTIFIER_SOUND_COMPLETION="end"

# ============================================================================
# Feature checks
# ============================================================================

is_enabled()            { [ "$CC_NOTIFIER_ENABLED" = "true" ]; }
is_tts_enabled()        { [ "$CC_NOTIFIER_TTS_ENABLED" = "true" ]; }
is_tts_message_enabled() { [ "$CC_NOTIFIER_TTS_MESSAGE_ENABLED" = "true" ]; }
is_visual_enabled()     { [ "$CC_NOTIFIER_VISUAL_ENABLED" = "true" ]; }
is_sound_enabled()      { [ "$CC_NOTIFIER_SOUND_ENABLED" = "true" ]; }
is_slack_enabled()      { [ "$CC_NOTIFIER_SLACK_ENABLED" = "true" ] && [ -n "$CC_NOTIFIER_SLACK_WEBHOOK_URL" ]; }
is_webhook_enabled()    { [ "$CC_NOTIFIER_WEBHOOK_ENABLED" = "true" ] && [ -n "$CC_NOTIFIER_WEBHOOK_URL" ]; }

# ============================================================================
# Quiet hours (suppress TTS and notification sounds)
# ============================================================================

is_quiet_hours() {
  [ -z "$CC_NOTIFIER_QUIET_START" ] && return 1
  [ -z "$CC_NOTIFIER_QUIET_END" ] && return 1
  local now start end
  now=$(date +%H%M)
  start="${CC_NOTIFIER_QUIET_START/:/}"
  end="${CC_NOTIFIER_QUIET_END/:/}"
  # Validate format (4-digit numbers)
  case "$start" in ''|*[!0-9]*) return 1 ;; esac
  case "$end" in ''|*[!0-9]*) return 1 ;; esac
  if [ "$start" -le "$end" ]; then
    [ "$now" -ge "$start" ] && [ "$now" -lt "$end" ]
  else
    [ "$now" -ge "$start" ] || [ "$now" -lt "$end" ]
  fi
}
