#!/bin/bash
# Windows / WSL2 implementation (PowerShell Toast + System.Speech TTS)
# shellcheck disable=SC2016  # PowerShell $variables in single-quoted strings are intentional

if [ -z "$CC_NOTIFIER_VOICE" ] && [ -n "$CC_NOTIFIER_WINDOWS_VOICE" ]; then
  CC_NOTIFIER_VOICE="$CC_NOTIFIER_WINDOWS_VOICE"
fi

_TTS_PID_FILE="$STATE_DIR/.tts-pid-windows"

_trim_spaces() {
  printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

_is_cmd_available() {
  local cmd="$1"
  case "$cmd" in
    */*|*\\*)
      [ -x "$cmd" ]
      ;;
    *)
      command -v "$cmd" >/dev/null 2>&1
      ;;
  esac
}

_is_visual_event_enabled() {
  local event="$1"
  [ "$CC_NOTIFIER_VISUAL_EVENTS" = "all" ] && return 0

  local IFS=','
  local e
  for e in $CC_NOTIFIER_VISUAL_EVENTS; do
    e=$(_trim_spaces "$e")
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
    e=$(_trim_spaces "$e")
    [ "$e" = "$event" ] && return 0
  done
  return 1
}

_warn_windows() {
  echo "cc-notifier-voice: $1" >&2
}

_b64_utf8() {
  if ! command -v base64 >/dev/null 2>&1; then
    return 1
  fi
  printf '%s' "$1" | base64 | tr -d '\r\n'
}

_b64_utf16le() {
  if ! command -v base64 >/dev/null 2>&1; then
    return 1
  fi
  if ! command -v iconv >/dev/null 2>&1; then
    return 1
  fi
  printf '%s' "$1" | iconv -f UTF-8 -t UTF-16LE 2>/dev/null | base64 | tr -d '\r\n'
}

_encode_powershell_script() {
  local script="$1"
  _b64_utf16le "$script"
}

# Windows PowerShell 5.1 does not support passing arguments alongside
# -EncodedCommand. Inject an $args array declaration into the script so
# the existing $args[N] references keep working.
_ps_inject_args() {
  local decl='$args = @('
  local first=true
  local arg
  for arg in "$@"; do
    if [ "$first" = true ]; then first=false; else decl+=','; fi
    decl+="'$arg'"
  done
  decl+=")"
  printf '%s\n' "$decl"
}

_run_powershell_encoded() {
  local script="$1"
  shift

  script="$(_ps_inject_args "$@")${script}"

  local encoded_script
  encoded_script=$(_encode_powershell_script "$script") || {
    _warn_windows "iconv/base64 unavailable, skipping Windows notification integration"
    return 1
  }

  "$CC_NOTIFIER_WINDOWS_POWERSHELL_PATH" \
    -NoProfile \
    -NonInteractive \
    -ExecutionPolicy Bypass \
    -EncodedCommand "$encoded_script" >/dev/null 2>&1
}

_run_powershell_encoded_bg() {
  local script="$1"
  shift

  script="$(_ps_inject_args "$@")${script}"

  local encoded_script
  encoded_script=$(_encode_powershell_script "$script") || {
    _warn_windows "iconv/base64 unavailable, skipping Windows TTS integration"
    return 1
  }

  "$CC_NOTIFIER_WINDOWS_POWERSHELL_PATH" \
    -NoProfile \
    -NonInteractive \
    -ExecutionPolicy Bypass \
    -EncodedCommand "$encoded_script" >/dev/null 2>&1 &
  echo $!
}

_windows_sound_uri() {
  case "$1" in
    info) printf '%s\n' 'ms-winsoundevent:Notification.Default' ;;
    warning) printf '%s\n' 'ms-winsoundevent:Notification.Reminder' ;;
    complete|end) printf '%s\n' 'ms-winsoundevent:Notification.IM' ;;
    *) printf '%s\n' '' ;;
  esac
}

send_notification() {
  local title="$1"
  local subtitle="$2"
  local message="$3"
  local sound="$4"
  local event="$5"
  : "$sound"

  is_visual_enabled || return 0
  [ -n "$event" ] && { _is_visual_event_enabled "$event" || return 0; }

  if ! _is_cmd_available "$CC_NOTIFIER_WINDOWS_POWERSHELL_PATH"; then
    _warn_windows "powershell not found: $CC_NOTIFIER_WINDOWS_POWERSHELL_PATH"
    return 0
  fi

  local title_b64 subtitle_b64 message_b64 appid_b64 sound_uri sound_b64
  title_b64=$(_b64_utf8 "$title") || { _warn_windows "failed to encode title"; return 0; }
  subtitle_b64=$(_b64_utf8 "$subtitle") || { _warn_windows "failed to encode subtitle"; return 0; }
  message_b64=$(_b64_utf8 "$message") || { _warn_windows "failed to encode message"; return 0; }
  appid_b64=$(_b64_utf8 "$CC_NOTIFIER_WINDOWS_APP_ID") || { _warn_windows "failed to encode app id"; return 0; }
  if is_sound_enabled && [ -n "$sound" ]; then
    sound_uri=$(_windows_sound_uri "$sound")
  else
    sound_uri=""
  fi
  sound_b64=$(_b64_utf8 "$sound_uri") || { _warn_windows "failed to encode sound"; return 0; }

  local ps_script
  ps_script='
$ErrorActionPreference = "Stop"
function Decode([string]$b64) {
  if ([string]::IsNullOrEmpty($b64)) { return "" }
  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
}
try {
  $title = Decode $args[0]
  $subtitle = Decode $args[1]
  $message = Decode $args[2]
  $appId = Decode $args[3]
  $soundUri = Decode $args[4]
  if ([string]::IsNullOrEmpty($appId)) { $appId = "cc-notifier-voice" }
  $psAppId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

  # Try to register custom AppID in HKCU (no admin required)
  $useAppId = $psAppId
  try {
    $regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\$appId"
    if (-not (Test-Path $regPath)) {
      New-Item -Path $regPath -Force > $null
      Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "Claude Code Notifier" -Force
    }
    $useAppId = $appId
  } catch {}

  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
  [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null

  $escTitle = [System.Security.SecurityElement]::Escape($title)
  $escSubtitle = [System.Security.SecurityElement]::Escape($subtitle)
  $escMessage = [System.Security.SecurityElement]::Escape($message)
  $line2 = if ([string]::IsNullOrEmpty($escSubtitle)) { $escMessage } else { "$escSubtitle - $escMessage" }
  $audioXml = if ([string]::IsNullOrEmpty($soundUri)) { "<audio silent=`"true`"/>" } else { "<audio src=`"$soundUri`"/>" }
  $xml = "<toast>$audioXml<visual><binding template=`"ToastGeneric`"><text>$escTitle</text><text>$line2</text></binding></visual></toast>"
  $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
  $doc.LoadXml($xml)
  $toast = [Windows.UI.Notifications.ToastNotification]::new($doc)
  $shown = $false
  try {
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($useAppId)
    $notifier.Show($toast)
    $shown = $true
  } catch {}
  if (-not $shown) {
    try {
      $fallbackNotifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($psAppId)
      $fallbackNotifier.Show($toast)
      $shown = $true
    } catch {}
  }
  if (-not $shown) { exit 2 }
} catch {
  exit 2
}
'

  _run_powershell_encoded "$ps_script" "$title_b64" "$subtitle_b64" "$message_b64" "$appid_b64" "$sound_b64" || {
    _warn_windows "toast notification failed"
    return 0
  }
}

send_tts() {
  local message="$1"
  local event="$2"

  is_tts_enabled || return 0
  [ -n "$event" ] && { _is_tts_event_enabled "$event" || return 0; }
  _ensure_state_dir || return 0

  if ! _is_cmd_available "$CC_NOTIFIER_WINDOWS_POWERSHELL_PATH"; then
    _warn_windows "powershell not found: $CC_NOTIFIER_WINDOWS_POWERSHELL_PATH"
    return 0
  fi

  _cancel_tts

  local message_b64 voice_b64 rate_b64
  message_b64=$(_b64_utf8 "$message") || { _warn_windows "failed to encode TTS message"; return 0; }
  voice_b64=$(_b64_utf8 "$CC_NOTIFIER_VOICE") || { _warn_windows "failed to encode TTS voice"; return 0; }
  rate_b64=$(_b64_utf8 "$CC_NOTIFIER_SPEED") || { _warn_windows "failed to encode TTS speed"; return 0; }

  local ps_script
  ps_script='
$ErrorActionPreference = "Stop"
function Decode([string]$b64) {
  if ([string]::IsNullOrEmpty($b64)) { return "" }
  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
}
try {
  Add-Type -AssemblyName System.Speech
  $message = Decode $args[0]
  $voice = Decode $args[1]
  $speedRaw = Decode $args[2]

  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  if (-not [string]::IsNullOrEmpty($voice)) {
    try { $synth.SelectVoice($voice) } catch {}
  }

  $rate = 0
  if ($speedRaw -match "^[0-9]+$") {
    $wpm = [int]$speedRaw
    # Map approximate WPM range (100-350) to SpeechSynthesizer.Rate (-10..10)
    $rate = [int][Math]::Round((($wpm - 225) / 12.5))
    if ($rate -lt -10) { $rate = -10 }
    if ($rate -gt 10) { $rate = 10 }
  }
  $synth.Rate = $rate
  $synth.Speak($message)
} catch {
  exit 2
}
'

  local ps_pid
  ps_pid=$(_run_powershell_encoded_bg "$ps_script" "$message_b64" "$voice_b64" "$rate_b64") || {
    _warn_windows "tts execution failed"
    return 0
  }
  case "$ps_pid" in
    ''|*[!0-9]*) _warn_windows "failed to capture tts process id"; return 0 ;;
  esac

  [ -L "$_TTS_PID_FILE" ] && { rm -f "$_TTS_PID_FILE"; return 0; }
  local tmp_pid
  tmp_pid=$(mktemp "${STATE_DIR}/.tts-pid-windows.XXXXXX" 2>/dev/null) || return 0
  echo "$ps_pid" > "$tmp_pid"
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

  local cmd
  cmd=$(ps -p "$pid" -o comm= 2>/dev/null | awk 'NR==1{print $1}')
  case "$cmd" in
    powershell*|*/powershell*|pwsh*|*/pwsh*) ;;
    *) rm -f "$_TTS_PID_FILE"; return 0 ;;
  esac

  kill "$pid" 2>/dev/null
  rm -f "$_TTS_PID_FILE"
}
