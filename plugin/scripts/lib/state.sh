#!/bin/bash
# SubAgent state management and session tracking

STATE_DIR="$HOME/.claude/.hook-state"

_cc_state_stat_owner() {
  stat -f '%u' "$1" 2>/dev/null || stat -c '%u' "$1" 2>/dev/null
}

_cc_state_stat_mode() {
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

_is_dir_safe() {
  local dir="$1"
  [ -z "$dir" ] && return 1
  # Reject symlinks
  [ -L "$dir" ] && return 1
  [ -d "$dir" ] || return 1
  # Must be owned by current user
  local owner mode
  owner=$(_cc_state_stat_owner "$dir") || return 1
  [ "$owner" = "$(id -u)" ] || return 1
  mode=$(_cc_state_stat_mode "$dir") || return 1
  _is_group_or_other_writable_mode "$mode" && return 1
  return 0
}

_ensure_state_dir_safe() {
  local parent
  parent=$(dirname "$STATE_DIR")
  if [ -e "$STATE_DIR" ]; then
    _is_dir_safe "$STATE_DIR" || { echo "cc-notifier-voice: state dir unsafe, disabling state features" >&2; return 1; }
  else
    # Ensure parent is safe before creating
    if [ -e "$parent" ] && ! _is_dir_safe "$parent"; then
      echo "cc-notifier-voice: state parent dir unsafe, disabling state features" >&2
      return 1
    fi
  fi
  return 0
}

_ensure_state_dir() {
  _ensure_state_dir_safe || return 1
  if [ -d "$STATE_DIR" ]; then
    chmod 700 "$STATE_DIR" 2>/dev/null
    return 0
  fi
  mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"
}

# ============================================================================
# Utility
# ============================================================================

get_project_name() {
  local name
  name=$(basename "${CLAUDE_PROJECT_DIR:-$MSG_PROJECT_UNKNOWN}" 2>/dev/null)
  name=$(printf '%s' "$name" | tr -cd '[:print:]')
  [ -n "$name" ] || name="$MSG_PROJECT_UNKNOWN"
  printf '%s\n' "$name"
}

_read_stdin_limited() {
  local max_bytes="${CC_NOTIFIER_MAX_STDIN_BYTES:-16384}"
  local capped_bytes
  capped_bytes=$((max_bytes + 1))

  # Read at most max+1 bytes into a temp file first to avoid loading an unbounded
  # single-line payload into shell memory before size validation.
  local tmp_file
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/cc-notifier-stdin.XXXXXX" 2>/dev/null) || {
    echo ""
    return 0
  }
  head -c "$capped_bytes" > "$tmp_file"

  local actual_bytes
  actual_bytes=$(wc -c < "$tmp_file" | tr -d '[:space:]')
  case "$actual_bytes" in ''|*[!0-9]*) actual_bytes=0 ;; esac

  if [ "$actual_bytes" -gt "$max_bytes" ]; then
    echo "cc-notifier-voice: stdin payload too large, ignoring" >&2
    rm -f "$tmp_file"
    echo ""
    return 0
  fi

  cat "$tmp_file"
  rm -f "$tmp_file"
}

# Read session_id from stdin JSON
read_session_id() {
  if ! command -v jq >/dev/null 2>&1; then
    echo ""
    return 0
  fi
  local input
  input=$(_read_stdin_limited)
  [ -z "$input" ] && { echo ""; return 0; }
  local sid
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  # Sanitize: allow only safe characters
  if [ -n "$sid" ] && ! printf '%s' "$sid" | grep -Eq '^[A-Za-z0-9_-]+$'; then
    sid=""
  fi
  echo "$sid"
}

# Read notification message from stdin JSON
# Returns the message field, or empty string if unavailable
read_notification_message() {
  command -v jq >/dev/null 2>&1 || { echo ""; return 0; }
  local input
  input=$(_read_stdin_limited)
  [ -z "$input" ] && { echo ""; return 0; }
  local msg
  msg=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
  echo "$msg"
}

# ============================================================================
# Session lock (mkdir-based, macOS bash 3.2 compatible)
# ============================================================================

_lock_session() {
  _ensure_state_dir_safe || return 1
  [ -d "$STATE_DIR" ] || return 1
  local lock_dir="$STATE_DIR/.lock-$1"
  local i=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    sleep 0.05
    i=$((i + 1))
    if [ "$i" -ge 20 ]; then
      # Recover stale lock (>5 min old)
      local lock_age
      lock_age=$(find "$lock_dir" -maxdepth 0 -type d -mmin +5 2>/dev/null)
      if [ -n "$lock_age" ]; then
        rmdir "$lock_dir" 2>/dev/null && continue
      fi
      return 1
    fi
  done
}

_unlock_session() {
  rmdir "$STATE_DIR/.lock-$1" 2>/dev/null
}

# ============================================================================
# SubAgent state management
# ============================================================================

get_subagent_count() {
  local session_id="$1"
  local count_file="$STATE_DIR/subagent-count-${session_id}"
  local raw
  raw=$(cat "$count_file" 2>/dev/null) || raw=0
  case "$raw" in
    ''|*[!0-9]*) raw=0 ;;
  esac
  echo "$raw"
}

increment_subagent_count() {
  local session_id="$1"
  _ensure_state_dir || return 0
  _lock_session "$session_id" || return 0
  local count_file="$STATE_DIR/subagent-count-${session_id}"
  local count
  count=$(get_subagent_count "$session_id")
  echo $((count + 1)) > "$count_file"
  _unlock_session "$session_id"
}

decrement_subagent_count() {
  local session_id="$1"
  _ensure_state_dir_safe || return 0
  _lock_session "$session_id" || return 0
  local count_file="$STATE_DIR/subagent-count-${session_id}"
  local count
  count=$(get_subagent_count "$session_id")
  [ "$count" -gt 0 ] && echo $((count - 1)) > "$count_file"
  _unlock_session "$session_id"
}

cleanup_session_state() {
  local session_id="$1"
  local count_file="$STATE_DIR/subagent-count-${session_id}"
  _ensure_state_dir_safe || return 0
  _lock_session "$session_id" || { rm -f "$count_file" 2>/dev/null; return 0; }
  rm -f "$count_file" 2>/dev/null
  _unlock_session "$session_id"
}

# ============================================================================
# Cooldown (rate limiting per event)
# ============================================================================

_check_cooldown() {
  local event="$1"
  [ "$CC_NOTIFIER_COOLDOWN" -le 0 ] 2>/dev/null && return 0
  _ensure_state_dir || return 0
  local ts_file="$STATE_DIR/.cooldown-${event}"
  local now last_ts
  now=$(date +%s)
  last_ts=$(cat "$ts_file" 2>/dev/null) || last_ts=0
  case "$last_ts" in ''|*[!0-9]*) last_ts=0 ;; esac
  [ $((now - last_ts)) -lt "$CC_NOTIFIER_COOLDOWN" ] && return 1
  rm -f "$ts_file" 2>/dev/null
  echo "$now" > "$ts_file"
  return 0
}

# ============================================================================
# Stale cleanup (24h subagent files, 5min stale locks, cooldown files)
# ============================================================================

cleanup_stale_state() {
  _ensure_state_dir_safe || return 0
  [ -d "$STATE_DIR" ] || return 0
  find "$STATE_DIR" -name "subagent-count-*" -type f -mmin +1440 -delete 2>/dev/null
  find "$STATE_DIR" -name ".lock-*" -type d -mmin +5 -exec rmdir {} + 2>/dev/null
  find "$STATE_DIR" -name ".cooldown-*" -type f -mmin +1440 -delete 2>/dev/null
  return 0
}
