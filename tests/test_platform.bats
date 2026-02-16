#!/usr/bin/env bats

setup() {
  load test_helper
  source "$LIB_DIR/platform.sh"
}

# Helper: run detect_platform with mocked uname/_is_wsl_kernel
run_platform_case() {
  local uname_value="$1"
  local ostype_value="$2"
  local wsl_interop="$3"
  local wsl_distro="$4"
  local wsl_kernel_result="$5"

  (
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

@test "Darwin detected as macos" {
  run run_platform_case "Darwin" "" "" "" 1
  [ "$output" = "macos" ]
}

@test "MINGW detected as windows" {
  run run_platform_case "MINGW64_NT-10.0" "" "" "" 1
  [ "$output" = "windows" ]
}

@test "Linux with WSL_INTEROP detected as wsl" {
  run run_platform_case "Linux" "" "interop" "" 1
  [ "$output" = "wsl" ]
}

@test "Linux with WSL kernel detected as wsl" {
  run run_platform_case "Linux" "" "" "" 0
  [ "$output" = "wsl" ]
}

@test "Plain Linux detected as linux" {
  run run_platform_case "Linux" "" "" "" 1
  [ "$output" = "linux" ]
}

@test "Unknown uname with msys OSTYPE falls back to windows" {
  run run_platform_case "Unknown" "msys" "" "" 1
  [ "$output" = "windows" ]
}
