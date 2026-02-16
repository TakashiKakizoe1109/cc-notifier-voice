#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$SCRIPT_DIR/test_platform.sh"
bash "$SCRIPT_DIR/test_windows_backend.sh"
