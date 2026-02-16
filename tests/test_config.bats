#!/usr/bin/env bats

setup() {
  load test_helper
  setup_temp_dirs
  unset_cc_notifier_vars
}

teardown() {
  teardown_temp_dirs
}

# ============================================================================
# Defaults
# ============================================================================

@test "default CC_NOTIFIER_ENABLED is true" {
  source_config
  [ "$CC_NOTIFIER_ENABLED" = "true" ]
}

@test "default CC_NOTIFIER_TTS_ENABLED is true" {
  source_config
  [ "$CC_NOTIFIER_TTS_ENABLED" = "true" ]
}

@test "default CC_NOTIFIER_SPEED is 250" {
  source_config
  [ "$CC_NOTIFIER_SPEED" = "250" ]
}

@test "default CC_NOTIFIER_COOLDOWN is 0" {
  source_config
  [ "$CC_NOTIFIER_COOLDOWN" = "0" ]
}

@test "default CC_NOTIFIER_REDACT_SENSITIVE is true" {
  source_config
  [ "$CC_NOTIFIER_REDACT_SENSITIVE" = "true" ]
}

@test "default CC_NOTIFIER_OUTBOUND_MESSAGE_MODE is summary_only" {
  source_config
  [ "$CC_NOTIFIER_OUTBOUND_MESSAGE_MODE" = "summary_only" ]
}

# ============================================================================
# Feature flags
# ============================================================================

@test "is_enabled returns true when ENABLED=true" {
  export CC_NOTIFIER_ENABLED=true
  source_config
  is_enabled
}

@test "is_enabled returns false when ENABLED=false" {
  export CC_NOTIFIER_ENABLED=false
  source_config
  ! is_enabled
}

@test "is_tts_enabled returns false when TTS_ENABLED=false" {
  export CC_NOTIFIER_TTS_ENABLED=false
  source_config
  ! is_tts_enabled
}

@test "is_visual_enabled returns false when VISUAL_ENABLED=false" {
  export CC_NOTIFIER_VISUAL_ENABLED=false
  source_config
  ! is_visual_enabled
}

@test "is_slack_enabled requires both flag and URL" {
  export CC_NOTIFIER_SLACK_ENABLED=true
  export CC_NOTIFIER_SLACK_WEBHOOK_URL=""
  source_config
  ! is_slack_enabled
}

@test "is_slack_enabled true when flag and URL set" {
  export CC_NOTIFIER_SLACK_ENABLED=true
  export CC_NOTIFIER_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
  source_config
  is_slack_enabled
}

# ============================================================================
# Numeric validation
# ============================================================================

@test "invalid speed falls back to 250" {
  export CC_NOTIFIER_SPEED="abc"
  source_config
  [ "$CC_NOTIFIER_SPEED" = "250" ]
}

@test "empty speed falls back to 250" {
  export CC_NOTIFIER_SPEED=""
  source_config
  [ "$CC_NOTIFIER_SPEED" = "250" ]
}

@test "valid speed is preserved" {
  export CC_NOTIFIER_SPEED="180"
  source_config
  [ "$CC_NOTIFIER_SPEED" = "180" ]
}

@test "invalid cooldown falls back to 0" {
  export CC_NOTIFIER_COOLDOWN="xyz"
  source_config
  [ "$CC_NOTIFIER_COOLDOWN" = "0" ]
}

@test "stdin byte limit below 1024 is clamped" {
  export CC_NOTIFIER_MAX_STDIN_BYTES="100"
  source_config
  [ "$CC_NOTIFIER_MAX_STDIN_BYTES" = "1024" ]
}

@test "stdin byte limit above 1MiB is clamped" {
  export CC_NOTIFIER_MAX_STDIN_BYTES="9999999"
  source_config
  [ "$CC_NOTIFIER_MAX_STDIN_BYTES" = "1048576" ]
}

# ============================================================================
# Boolean / enum validation
# ============================================================================

@test "invalid REDACT_SENSITIVE falls back to true" {
  export CC_NOTIFIER_REDACT_SENSITIVE="yes"
  source_config
  [ "$CC_NOTIFIER_REDACT_SENSITIVE" = "true" ]
}

@test "invalid OUTBOUND_MESSAGE_MODE falls back to summary_only" {
  export CC_NOTIFIER_OUTBOUND_MESSAGE_MODE="invalid"
  source_config
  [ "$CC_NOTIFIER_OUTBOUND_MESSAGE_MODE" = "summary_only" ]
}

@test "OUTBOUND_MESSAGE_MODE=full is accepted" {
  export CC_NOTIFIER_OUTBOUND_MESSAGE_MODE="full"
  source_config
  [ "$CC_NOTIFIER_OUTBOUND_MESSAGE_MODE" = "full" ]
}

# ============================================================================
# Hash / Team ID validation
# ============================================================================

@test "invalid SHA256 hash falls back to default" {
  export CC_NOTIFIER_BINARY_SHA256="not-a-hash"
  source_config
  [ "$CC_NOTIFIER_BINARY_SHA256" = "$_CC_NOTIFIER_DEFAULT_BINARY_SHA256" ]
}

@test "valid SHA256 hash is preserved (lowercased)" {
  local hash="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  export CC_NOTIFIER_BINARY_SHA256="$hash"
  source_config
  [ "$CC_NOTIFIER_BINARY_SHA256" = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ]
}

@test "invalid CODESIGN_TEAM_ID is cleared" {
  export CC_NOTIFIER_CODESIGN_TEAM_ID="bad"
  source_config
  [ -z "$CC_NOTIFIER_CODESIGN_TEAM_ID" ]
}

@test "valid CODESIGN_TEAM_ID is uppercased and preserved" {
  export CC_NOTIFIER_CODESIGN_TEAM_ID="abcd1234ef"
  source_config
  [ "$CC_NOTIFIER_CODESIGN_TEAM_ID" = "ABCD1234EF" ]
}

# ============================================================================
# Language auto-detect
# ============================================================================

@test "LANG=ja* sets CC_NOTIFIER_LANG to ja" {
  export LANG="ja_JP.UTF-8"
  source_config
  [ "$CC_NOTIFIER_LANG" = "ja" ]
}

@test "LANG=en* sets CC_NOTIFIER_LANG to en" {
  export LANG="en_US.UTF-8"
  source_config
  [ "$CC_NOTIFIER_LANG" = "en" ]
}

# ============================================================================
# Config file parsing
# ============================================================================

@test "config file overrides env var" {
  export CC_NOTIFIER_SPEED="100"
  source_config_with_file "CC_NOTIFIER_SPEED=300"
  [ "$CC_NOTIFIER_SPEED" = "300" ]
}

@test "config file strips surrounding quotes" {
  source_config_with_file 'CC_NOTIFIER_VOICE="Kyoko"'
  [ "$CC_NOTIFIER_VOICE" = "Kyoko" ]
}

@test "config file strips single quotes" {
  source_config_with_file "CC_NOTIFIER_VOICE='Kyoko'"
  [ "$CC_NOTIFIER_VOICE" = "Kyoko" ]
}

@test "config file ignores comments and empty lines" {
  source_config_with_file "# This is a comment" "" "CC_NOTIFIER_SPEED=400"
  [ "$CC_NOTIFIER_SPEED" = "400" ]
}

@test "config file rejects unknown keys" {
  source_config_with_file "CC_NOTIFIER_EVIL_KEY=hack"
  [ -z "${CC_NOTIFIER_EVIL_KEY:-}" ]
}

# ============================================================================
# Quiet hours
# ============================================================================

@test "quiet hours: not active when not configured" {
  source_config
  ! is_quiet_hours
}

@test "quiet hours: invalid format returns false" {
  export CC_NOTIFIER_QUIET_START="abc"
  export CC_NOTIFIER_QUIET_END="def"
  source_config
  ! is_quiet_hours
}

# ============================================================================
# Sound names
# ============================================================================

@test "sound names are set for each event" {
  source_config
  [ "$CC_NOTIFIER_SOUND_NOTIFICATION" = "info" ]
  [ "$CC_NOTIFIER_SOUND_PERMISSION" = "warning" ]
  [ "$CC_NOTIFIER_SOUND_STOP" = "complete" ]
  [ "$CC_NOTIFIER_SOUND_TOOL_FAILURE" = "warning" ]
  [ "$CC_NOTIFIER_SOUND_COMPLETION" = "end" ]
}
