#!/usr/bin/env bats

setup() {
  load test_helper
  setup_temp_dirs
  unset_cc_notifier_vars

  # Source dependencies
  source_config
  export CC_NOTIFIER_LANG="en"
  source "$LIB_DIR/i18n.sh"
  source "$LIB_DIR/state.sh"
}

teardown() {
  teardown_temp_dirs
}

# ============================================================================
# get_project_name
# ============================================================================

@test "get_project_name returns basename of CLAUDE_PROJECT_DIR" {
  export CLAUDE_PROJECT_DIR="/path/to/my-project"
  run get_project_name
  [ "$status" -eq 0 ]
  [ "$output" = "my-project" ]
}

@test "get_project_name returns fallback when CLAUDE_PROJECT_DIR is unset" {
  unset CLAUDE_PROJECT_DIR
  run get_project_name
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

# ============================================================================
# SubAgent state management
# ============================================================================

@test "increment_subagent_count creates state file" {
  increment_subagent_count "test-session"
  [ -f "$STATE_DIR/subagent-count-test-session" ]
}

@test "get_subagent_count returns 0 for new session" {
  mkdir -p "$STATE_DIR"
  run get_subagent_count "new-session"
  [ "$output" = "0" ]
}

@test "increment then get returns 1" {
  increment_subagent_count "sess1"
  run get_subagent_count "sess1"
  [ "$output" = "1" ]
}

@test "increment twice returns 2" {
  increment_subagent_count "sess2"
  increment_subagent_count "sess2"
  run get_subagent_count "sess2"
  [ "$output" = "2" ]
}

@test "decrement from 2 returns 1" {
  increment_subagent_count "sess3"
  increment_subagent_count "sess3"
  decrement_subagent_count "sess3"
  run get_subagent_count "sess3"
  [ "$output" = "1" ]
}

@test "decrement does not go below 0" {
  increment_subagent_count "sess4"
  decrement_subagent_count "sess4"
  decrement_subagent_count "sess4"
  run get_subagent_count "sess4"
  [ "$output" = "0" ]
}

@test "cleanup_session_state removes count file" {
  increment_subagent_count "sess5"
  [ -f "$STATE_DIR/subagent-count-sess5" ]
  cleanup_session_state "sess5"
  [ ! -f "$STATE_DIR/subagent-count-sess5" ]
}

# ============================================================================
# Cooldown
# ============================================================================

@test "cooldown disabled when CC_NOTIFIER_COOLDOWN=0" {
  export CC_NOTIFIER_COOLDOWN=0
  _check_cooldown "notification"
}

@test "cooldown blocks rapid repeat" {
  export CC_NOTIFIER_COOLDOWN=60
  mkdir -p "$STATE_DIR"
  _check_cooldown "test-event"
  ! _check_cooldown "test-event"
}

# ============================================================================
# State directory safety
# ============================================================================

@test "_ensure_state_dir creates STATE_DIR with mode 700" {
  _ensure_state_dir
  [ -d "$STATE_DIR" ]
  local mode
  mode=$(stat -f '%Lp' "$STATE_DIR" 2>/dev/null || stat -c '%a' "$STATE_DIR" 2>/dev/null)
  [ "$mode" = "700" ]
}
