#!/bin/bash
# Internationalization messages

case "$CC_NOTIFIER_LANG" in
  ja)
    MSG_NOTIFICATION="入力待ち"
    MSG_PERMISSION="操作の許可が必要です"
    MSG_STOP="応答完了"
    MSG_TOOL_FAILURE="ツール失敗"
    MSG_TOOL_FAILURE_TTS="ツールが失敗しました"
    MSG_TOOL_UNKNOWN="不明なツール"
    MSG_COMPLETION="セッション終了"
    MSG_PROJECT_UNKNOWN="不明"
    MSG_SEPARATOR="、"
    ;;
  *)
    MSG_NOTIFICATION="Waiting for input"
    MSG_PERMISSION="Permission required"
    MSG_STOP="Response completed"
    MSG_TOOL_FAILURE="Tool failed"
    MSG_TOOL_FAILURE_TTS="A tool has failed"
    MSG_TOOL_UNKNOWN="unknown tool"
    MSG_COMPLETION="Session ended"
    MSG_PROJECT_UNKNOWN="unknown"
    MSG_SEPARATOR=", "
    ;;
esac
