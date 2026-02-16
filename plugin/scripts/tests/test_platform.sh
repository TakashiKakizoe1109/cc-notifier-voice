#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_LIB="$SCRIPT_DIR/../lib/platform.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  local name="$3"
  [ "$got" = "$want" ] || fail "$name (got='$got', want='$want')"
}

run_case() {
  local uname_value="$1"
  local ostype_value="$2"
  local wsl_interop="$3"
  local wsl_distro="$4"
  local wsl_kernel_result="$5"

  (
    # shellcheck disable=SC1090
    source "$PLATFORM_LIB"
    uname() { echo "$uname_value"; }
    _is_wsl_kernel() { return "$wsl_kernel_result"; }

    if [ -n "$ostype_value" ]; then
      export OSTYPE="$ostype_value"
    else
      unset OSTYPE
    fi
    if [ -n "$wsl_interop" ]; then
      export WSL_INTEROP="$wsl_interop"
    else
      unset WSL_INTEROP
    fi
    if [ -n "$wsl_distro" ]; then
      export WSL_DISTRO_NAME="$wsl_distro"
    else
      unset WSL_DISTRO_NAME
    fi

    detect_platform
  )
}

assert_eq "$(run_case Darwin "" "" "" 1)" "macos" "darwin detection"
assert_eq "$(run_case MINGW64_NT-10.0 "" "" "" 1)" "windows" "mingw detection"
assert_eq "$(run_case Linux "" "interop" "" 1)" "wsl" "wsl env detection"
assert_eq "$(run_case Linux "" "" "" 0)" "wsl" "wsl kernel fallback detection"
assert_eq "$(run_case Linux "" "" "" 1)" "linux" "plain linux detection"
assert_eq "$(run_case Unknown "msys" "" "" 1)" "windows" "ostype fallback detection"

echo "PASS: platform detection smoke tests"
