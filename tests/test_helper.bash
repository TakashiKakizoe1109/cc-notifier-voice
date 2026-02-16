#!/bin/bash
# Shared test helper for all .bats files

LIB_DIR="$BATS_TEST_DIRNAME/../plugin/scripts/lib"

# _is_group_or_other_writable_mode is defined in cc-notifier.sh (the main
# dispatcher) and used by config.sh and state.sh.  Provide it here so
# individual library files can be sourced in isolation during tests.
_is_group_or_other_writable_mode() {
  local mode="$1"
  case "$mode" in
    ''|*[!0-7]*) return 0 ;;
  esac
  local perm="${mode#${mode%???}}"
  [ ${#perm} -eq 3 ] || return 0
  [ $((8#$perm & 8#022)) -ne 0 ]
}

# Create isolated temp directories with fake HOME
setup_temp_dirs() {
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/cc-notifier-test.XXXXXX")"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"
  export STATE_DIR="$TEST_TMP/state"
}

teardown_temp_dirs() {
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

# Clear all CC_NOTIFIER_ env vars to test defaults cleanly
unset_cc_notifier_vars() {
  local var
  for var in $(env | grep '^CC_NOTIFIER_' | cut -d= -f1); do
    unset "$var"
  done
  unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT CLAUDE_NOTIFICATION_MESSAGE
  unset CLAUDE_TOOL_NAME CLAUDE_SESSION_ID
}

# Source config.sh with a clean environment (no config file)
source_config() {
  source "$LIB_DIR/config.sh"
}

# Source config.sh with a temp config file
source_config_with_file() {
  local config_dir="$TEST_TMP/config"
  mkdir -p "$config_dir"
  chmod 700 "$config_dir"
  local config_file="$config_dir/config"
  printf '%s\n' "$@" > "$config_file"
  chmod 600 "$config_file"
  export CC_NOTIFIER_CONFIG="$config_file"
  source "$LIB_DIR/config.sh"
}
