#!/bin/bash
# Slack webhook notification module

# ============================================================================
# JSON escaping (manual, no jq dependency)
# ============================================================================

_slack_escape_json() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//\`/\\\`}"
  text="${text//\$/\\\$}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/}"
  text="${text//$'\t'/\\t}"
  # Strip remaining control characters (0x00-0x1F except already-handled \n \r \t)
  text=$(printf '%s' "$text" | tr -d '\000-\010\013\014\016-\037')
  printf '%s' "$text"
}

_redact_sensitive_text() {
  local text="$1"
  [ "$CC_NOTIFIER_REDACT_SENSITIVE" = "true" ] || { printf '%s' "$text"; return 0; }

  # Best-effort masking for common token formats.
  text=$(printf '%s' "$text" | sed -E \
    -e 's/xox[baprs]-[A-Za-z0-9-]+/[REDACTED_SLACK_TOKEN]/g' \
    -e 's/sk-[A-Za-z0-9_-]{16,}/[REDACTED_API_KEY]/g' \
    -e 's/gh[pousr]_[A-Za-z0-9]{20,}/[REDACTED_GITHUB_TOKEN]/g' \
    -e 's/AKIA[0-9A-Z]{16}/[REDACTED_AWS_ACCESS_KEY]/g' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]+/\1[REDACTED]/g' \
    -e 's/(token|apikey|api_key|access_token|refresh_token|client_secret|password)=([^&[:space:]]+)/\1=[REDACTED]/Ig' \
    -e 's/[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/[REDACTED_JWT]/g' \
    -e 's/\b[A-Fa-f0-9]{32,}\b/[REDACTED_HEX_SECRET]/g')
  printf '%s' "$text"
}

# ============================================================================
# Event filter
# ============================================================================

_is_slack_event_enabled() {
  local event="$1"
  [ "$CC_NOTIFIER_SLACK_EVENTS" = "all" ] && return 0

  local IFS=','
  local e
  for e in $CC_NOTIFIER_SLACK_EVENTS; do
    # Trim whitespace
    e="${e## }"; e="${e%% }"
    [ "$e" = "$event" ] && return 0
  done
  return 1
}

# ============================================================================
# Webhook URL validation
# ============================================================================

# Reject URLs with characters unsafe for curl --config injection
_url_has_unsafe_chars() {
  case "$1" in
    *\"*|*\'*) return 0 ;;
  esac
  # Reject whitespace (space 0x20) and control characters (0x00-0x1F, 0x7F)
  local cleaned
  cleaned=$(printf '%s' "$1" | tr -d '\000-\040\177')
  [ "$cleaned" != "$1" ] && return 0
  return 1
}

_validate_slack_url() {
  case "$1" in
    https://hooks.slack.com/*) ;;
    *) return 1 ;;
  esac
  _url_has_unsafe_chars "$1" && return 1
  return 0
}

_validate_webhook_url() {
  case "$1" in
    https://*) ;;
    *) return 1 ;;
  esac
  _url_has_unsafe_chars "$1" && return 1
  _is_webhook_host_allowed "$1" || return 1
  return 0
}

_extract_url_host() {
  local url="$1"
  local host
  host=$(printf '%s' "$url" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://([^/@]+@)?([^/:?#]+).*$#\2#')
  [ -z "$host" ] && return 1
  host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')
  printf '%s' "$host"
}

_is_valid_hostname_pattern() {
  case "$1" in
    ''|-*|*..*|*.) return 1 ;;
  esac
  case "$1" in
    *[!A-Za-z0-9.-]*|.*|*-) return 1 ;;
    *) return 0 ;;
  esac
}

_is_host_allowed_by_list() {
  local host="$1"
  local allowed_list="$2"
  local IFS=','
  local allowed
  for allowed in $allowed_list; do
    allowed="${allowed## }"; allowed="${allowed%% }"
    allowed=$(printf '%s' "$allowed" | tr '[:upper:]' '[:lower:]')
    _is_valid_hostname_pattern "$allowed" || continue
    [ "$host" = "$allowed" ] && return 0
    case "$host" in
      *."$allowed") return 0 ;;
    esac
  done
  return 1
}

_is_webhook_host_allowed() {
  local host
  host=$(_extract_url_host "$1") || return 1

  # If no explicit allowlist is provided, fall back to the configured webhook
  # URL host so users only need to set one value in common setups.
  local allowed_list="$CC_NOTIFIER_WEBHOOK_ALLOWED_HOSTS"
  if [ -z "$allowed_list" ]; then
    allowed_list="$(_extract_url_host "$CC_NOTIFIER_WEBHOOK_URL")" || return 1
  fi

  _is_host_allowed_by_list "$host" "$allowed_list"
}

_summary_message_for_event() {
  case "$1" in
    notification) printf '%s' "Claude Code needs attention." ;;
    permission) printf '%s' "Claude Code is waiting for permission." ;;
    stop) printf '%s' "Claude Code response completed." ;;
    tool-failure) printf '%s' "Claude Code reported a tool failure." ;;
    completion) printf '%s' "Claude Code session ended." ;;
    *) printf '%s' "Claude Code event received." ;;
  esac
}

_prepare_outbound_message() {
  local event="$1"
  local message="$2"
  case "$CC_NOTIFIER_OUTBOUND_MESSAGE_MODE" in
    full) printf '%s' "$message" ;;
    summary_only|*) _summary_message_for_event "$event" ;;
  esac
}

# ============================================================================
# Send Slack notification
# Usage: send_slack "event" "title" "message"
# ============================================================================

send_slack() {
  local event="$1"
  local title="$2"
  local message="$3"

  is_slack_enabled || return 0
  _is_slack_event_enabled "$event" || return 0
  _validate_slack_url "$CC_NOTIFIER_SLACK_WEBHOOK_URL" || return 0

  message=$(_prepare_outbound_message "$event" "$message")
  title=$(_redact_sensitive_text "$title")
  message=$(_redact_sensitive_text "$message")

  # Truncate message to 500 characters
  [ ${#message} -gt 500 ] && message="${message:0:500}"

  local safe_title safe_message safe_event
  safe_title=$(_slack_escape_json "$title")
  safe_message=$(_slack_escape_json "$message")
  safe_event=$(_slack_escape_json "$event")

  local payload
  payload=$(printf '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"Claude Code: %s"}},{"type":"section","text":{"type":"plain_text","text":"Event: %s\\n%s"}}]}' \
    "$safe_title" "$safe_event" "$safe_message")

  # Fire-and-forget with timeout, pass URL via stdin to hide from process list
  printf 'url = "%s"\n' "$CC_NOTIFIER_SLACK_WEBHOOK_URL" | \
    curl -s --max-time 5 -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      --config - >/dev/null 2>&1 &
}

# ============================================================================
# Generic webhook event filter
# ============================================================================

_is_webhook_event_enabled() {
  local event="$1"
  [ "$CC_NOTIFIER_WEBHOOK_EVENTS" = "all" ] && return 0

  local IFS=','
  local e
  for e in $CC_NOTIFIER_WEBHOOK_EVENTS; do
    e="${e## }"; e="${e%% }"
    [ "$e" = "$event" ] && return 0
  done
  return 1
}

# ============================================================================
# Send generic webhook notification
# Usage: send_webhook "event" "title" "message"
# ============================================================================

send_webhook() {
  local event="$1"
  local title="$2"
  local message="$3"

  is_webhook_enabled || return 0
  _is_webhook_event_enabled "$event" || return 0
  _validate_webhook_url "$CC_NOTIFIER_WEBHOOK_URL" || return 0

  message=$(_prepare_outbound_message "$event" "$message")
  title=$(_redact_sensitive_text "$title")
  message=$(_redact_sensitive_text "$message")

  # Truncate message to 500 characters
  [ ${#message} -gt 500 ] && message="${message:0:500}"

  local safe_event safe_title safe_message
  safe_event=$(_slack_escape_json "$event")
  safe_title=$(_slack_escape_json "$title")
  safe_message=$(_slack_escape_json "$message")

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")

  local payload
  payload=$(printf '{"event":"%s","project":"%s","message":"%s","timestamp":"%s"}' \
    "$safe_event" "$safe_title" "$safe_message" "$timestamp")

  # Fire-and-forget, pass URL via stdin to hide from process list
  printf 'url = "%s"\n' "$CC_NOTIFIER_WEBHOOK_URL" | \
    curl -s --max-time 5 -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      --config - >/dev/null 2>&1 &
}
