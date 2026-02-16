#!/usr/bin/env bats

setup() {
  load test_helper
  setup_temp_dirs
  unset_cc_notifier_vars
}

teardown() {
  teardown_temp_dirs
}

@test "Japanese messages when CC_NOTIFIER_LANG=ja" {
  export CC_NOTIFIER_LANG="ja"
  source "$LIB_DIR/i18n.sh"
  [ "$MSG_NOTIFICATION" = "入力待ち" ]
  [ "$MSG_STOP" = "応答完了" ]
  [ "$MSG_SEPARATOR" = "、" ]
}

@test "English messages when CC_NOTIFIER_LANG=en" {
  export CC_NOTIFIER_LANG="en"
  source "$LIB_DIR/i18n.sh"
  [ "$MSG_NOTIFICATION" = "Waiting for input" ]
  [ "$MSG_STOP" = "Response completed" ]
  [ "$MSG_SEPARATOR" = ", " ]
}

@test "Unknown language falls back to English" {
  export CC_NOTIFIER_LANG="fr"
  source "$LIB_DIR/i18n.sh"
  [ "$MSG_NOTIFICATION" = "Waiting for input" ]
}

@test "All message variables are set for English" {
  export CC_NOTIFIER_LANG="en"
  source "$LIB_DIR/i18n.sh"
  [ -n "$MSG_NOTIFICATION" ]
  [ -n "$MSG_PERMISSION" ]
  [ -n "$MSG_STOP" ]
  [ -n "$MSG_TOOL_FAILURE" ]
  [ -n "$MSG_TOOL_FAILURE_TTS" ]
  [ -n "$MSG_TOOL_UNKNOWN" ]
  [ -n "$MSG_COMPLETION" ]
  [ -n "$MSG_PROJECT_UNKNOWN" ]
  [ -n "$MSG_SEPARATOR" ]
}

@test "All message variables are set for Japanese" {
  export CC_NOTIFIER_LANG="ja"
  source "$LIB_DIR/i18n.sh"
  [ -n "$MSG_NOTIFICATION" ]
  [ -n "$MSG_PERMISSION" ]
  [ -n "$MSG_STOP" ]
  [ -n "$MSG_TOOL_FAILURE" ]
  [ -n "$MSG_TOOL_FAILURE_TTS" ]
  [ -n "$MSG_TOOL_UNKNOWN" ]
  [ -n "$MSG_COMPLETION" ]
  [ -n "$MSG_PROJECT_UNKNOWN" ]
  [ -n "$MSG_SEPARATOR" ]
}
