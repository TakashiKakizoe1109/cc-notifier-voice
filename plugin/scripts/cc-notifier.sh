#!/bin/bash
# cc-notifier - macOS notification + voice plugin for Claude Code hooks
# Usage: cc-notifier.sh {notification|permission|stop|tool-failure|completion|subagent-start|subagent-stop}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Safe source guards for local library files
_UNAME_S="$(uname -s)"

_stat_owner() {
  case "$_UNAME_S" in
    Darwin) stat -f '%u' "$1" 2>/dev/null ;;
    *)      stat -c '%u' "$1" 2>/dev/null ;;
  esac
}

_stat_mode() {
  case "$_UNAME_S" in
    Darwin) stat -f '%Lp' "$1" 2>/dev/null ;;
    *)      stat -c '%a' "$1" 2>/dev/null ;;
  esac
}

_is_group_or_other_writable_mode() {
  local mode="$1"
  case "$mode" in
    ''|*[!0-7]*) return 0 ;;
  esac
  local perm="${mode#"${mode%???}"}"
  [ ${#perm} -eq 3 ] || return 0
  [ $((8#$perm & 8#022)) -ne 0 ]
}

_is_safe_source_file() {
  local path="$1"
  [ -n "$path" ] || { _SAFE_FAIL="empty path"; return 1; }
  [ -f "$path" ] || { _SAFE_FAIL="not a regular file"; return 1; }
  [ -L "$path" ] && { _SAFE_FAIL="symlink"; return 1; }

  local owner mode
  owner=$(_stat_owner "$path") || { _SAFE_FAIL="cannot stat owner"; return 1; }
  mode=$(_stat_mode "$path") || { _SAFE_FAIL="cannot stat mode"; return 1; }

  # Accept files owned by current user or root (UID 0)
  local my_uid
  my_uid=$(id -u)
  [ "$owner" = "$my_uid" ] || [ "$owner" = "0" ] || {
    _SAFE_FAIL="owner=$owner, expected=$my_uid or 0"; return 1; }
  _is_group_or_other_writable_mode "$mode" && {
    _SAFE_FAIL="group/other writable (mode=$mode)"; return 1; }
  return 0
}

_source_safe() {
  local path="$1"
  _SAFE_FAIL=""
  if ! _is_safe_source_file "$path"; then
    echo "cc-notifier-voice: unsafe library file, refusing to load: $path (${_SAFE_FAIL})" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$path"
}

# Load config (env defaults, config file, feature checks)
_source_safe "$SCRIPT_DIR/lib/config.sh"
_source_safe "$SCRIPT_DIR/lib/platform.sh"

# Check if notifications are globally enabled
is_enabled || exit 0

_source_safe "$SCRIPT_DIR/lib/i18n.sh"      # language messages
_source_safe "$SCRIPT_DIR/lib/state.sh"     # SubAgent state management
_source_safe "$SCRIPT_DIR/lib/slack.sh"     # Slack + generic webhook

PLATFORM="$(detect_platform)"
case "$PLATFORM" in
  macos)
    _source_safe "$SCRIPT_DIR/lib/macos.sh"
    ;;
  windows|wsl)
    _source_safe "$SCRIPT_DIR/lib/windows.sh"
    ;;
  *)
    echo "cc-notifier-voice: platform '$PLATFORM' is not supported, skipping notification hooks" >&2
    exit 0
    ;;
esac

cleanup_stale_state

# Apply quiet hours: suppress TTS and notification sounds
if is_quiet_hours; then
  CC_NOTIFIER_TTS_ENABLED=false
  CC_NOTIFIER_SOUND_ENABLED=false
fi

# ============================================================================
# Event Handlers
# ============================================================================

handle_notification() {
  _check_cooldown "notification" || return 0

  local stdin_message
  stdin_message=$(read_notification_message)

  local project_name
  project_name=$(get_project_name)

  # Visual notification: stdin > env var > i18n default
  local visual_message="${stdin_message:-${CLAUDE_NOTIFICATION_MESSAGE:-$MSG_NOTIFICATION}}"
  [ ${#visual_message} -gt 1000 ] && visual_message="${visual_message:0:1000}"
  send_notification "Claude Code" "$project_name" "$visual_message" "$CC_NOTIFIER_SOUND_NOTIFICATION" "notification"

  # TTS: use stdin message content when enabled, with 200-char limit
  local tts_message
  if is_tts_message_enabled && [ -n "$stdin_message" ]; then
    tts_message="$stdin_message"
    [ ${#tts_message} -gt 200 ] && tts_message="${tts_message:0:200}"
  else
    tts_message="${CLAUDE_NOTIFICATION_MESSAGE:-$MSG_NOTIFICATION}"
  fi
  send_tts "${project_name}${MSG_SEPARATOR}${tts_message}" "notification"
  send_slack "notification" "$project_name" "$visual_message"
  send_webhook "notification" "$project_name" "$visual_message"
}

handle_permission() {
  _check_cooldown "permission" || return 0

  local stdin_message
  stdin_message=$(read_notification_message)

  local project_name
  project_name=$(get_project_name)

  # Visual notification: stdin > env var > i18n default
  local visual_message="${stdin_message:-${CLAUDE_NOTIFICATION_MESSAGE:-$MSG_PERMISSION}}"
  [ ${#visual_message} -gt 1000 ] && visual_message="${visual_message:0:1000}"
  send_notification "Claude Code" "$project_name" "$visual_message" "$CC_NOTIFIER_SOUND_PERMISSION" "permission"

  # TTS: use stdin message content when enabled, with 200-char limit
  local tts_message
  if is_tts_message_enabled && [ -n "$stdin_message" ]; then
    tts_message="$stdin_message"
    [ ${#tts_message} -gt 200 ] && tts_message="${tts_message:0:200}"
  else
    tts_message="${CLAUDE_NOTIFICATION_MESSAGE:-$MSG_PERMISSION}"
  fi
  send_tts "${project_name}${MSG_SEPARATOR}${tts_message}" "permission"
  send_slack "permission" "$project_name" "$visual_message"
  send_webhook "permission" "$project_name" "$visual_message"
}

handle_stop() {
  local session_id
  session_id=$(read_session_id)

  # Skip notification if SubAgents are running
  if [ -n "$session_id" ]; then
    local count
    count=$(get_subagent_count "$session_id")
    [ "$count" -gt 0 ] && exit 0
  fi

  _check_cooldown "stop" || return 0

  local project_name
  project_name=$(get_project_name)

  send_notification "Claude Code" "$project_name" "$MSG_STOP" "$CC_NOTIFIER_SOUND_STOP" "stop"
  send_tts "${project_name}${MSG_SEPARATOR}${MSG_STOP}" "stop"
  send_slack "stop" "$project_name" "$MSG_STOP"
  send_webhook "stop" "$project_name" "$MSG_STOP"
}

handle_tool_failure() {
  _check_cooldown "tool-failure" || return 0

  local project_name
  project_name=$(get_project_name)
  local tool_name="${CLAUDE_TOOL_NAME:-${MSG_TOOL_UNKNOWN}}"
  tool_name="${tool_name:0:100}"
  tool_name=$(printf '%s' "$tool_name" | tr -cd '[:print:]')

  send_notification "Claude Code" "$project_name" "${MSG_TOOL_FAILURE}: $tool_name" "$CC_NOTIFIER_SOUND_TOOL_FAILURE" "tool-failure"
  send_tts "${project_name}${MSG_SEPARATOR}${MSG_TOOL_FAILURE_TTS}" "tool-failure"
  send_slack "tool-failure" "$project_name" "${MSG_TOOL_FAILURE}: $tool_name"
  send_webhook "tool-failure" "$project_name" "${MSG_TOOL_FAILURE}: $tool_name"
}

handle_completion() {
  local session_id
  session_id=$(read_session_id)

  # Cleanup SubAgent state for this session
  if [ -n "$session_id" ]; then
    cleanup_session_state "$session_id"
  fi

  _check_cooldown "completion" || return 0

  local project_name
  project_name=$(get_project_name)

  send_notification "Claude Code" "$project_name" "$MSG_COMPLETION" "$CC_NOTIFIER_SOUND_COMPLETION" "completion"
  send_tts "${project_name}${MSG_SEPARATOR}${MSG_COMPLETION}" "completion"
  send_slack "completion" "$project_name" "$MSG_COMPLETION"
  send_webhook "completion" "$project_name" "$MSG_COMPLETION"
}

handle_subagent_start() {
  local session_id
  session_id=$(read_session_id)

  [ -z "$session_id" ] && exit 0

  increment_subagent_count "$session_id"
}

handle_subagent_stop() {
  local session_id
  session_id=$(read_session_id)

  [ -z "$session_id" ] && exit 0

  decrement_subagent_count "$session_id"
}

# ============================================================================
# Main dispatch
# ============================================================================

case "$1" in
  notification)    handle_notification ;;
  permission)      handle_permission ;;
  stop)            handle_stop ;;
  tool-failure)    handle_tool_failure ;;
  completion)      handle_completion ;;
  subagent-start)  handle_subagent_start ;;
  subagent-stop)   handle_subagent_stop ;;
  *)
    echo "Usage: $0 {notification|permission|stop|tool-failure|completion|subagent-start|subagent-stop}" >&2
    exit 1
    ;;
esac

wait
exit 0
