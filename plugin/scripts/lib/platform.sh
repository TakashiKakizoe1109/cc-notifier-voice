#!/bin/bash
# Platform detection helpers

_is_wsl_kernel() {
  local probe
  for probe in /proc/sys/kernel/osrelease /proc/version; do
    [ -r "$probe" ] || continue
    if tr '[:upper:]' '[:lower:]' < "$probe" 2>/dev/null | grep -q "microsoft"; then
      return 0
    fi
  done
  return 1
}

detect_platform() {
  local uname_s os

  uname_s=$(uname -s 2>/dev/null || echo unknown)
  os="unknown"

  case "$uname_s" in
    Darwin) os="macos" ;;
    Linux)
      if [ -n "${WSL_INTEROP:-}" ] || [ -n "${WSL_DISTRO_NAME:-}" ] || _is_wsl_kernel; then
        os="wsl"
      else
        os="linux"
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*) os="windows" ;;
    *) os="unknown" ;;
  esac

  if [ "$os" = "unknown" ] && [ -n "${OSTYPE:-}" ]; then
    case "$OSTYPE" in
      darwin*) os="macos" ;;
      msys*|cygwin*|win32*) os="windows" ;;
    esac
  fi

  printf '%s\n' "$os"
}
