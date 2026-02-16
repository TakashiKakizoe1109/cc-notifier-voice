#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats-core is required. Install with: brew install bats-core" >&2
  exit 1
fi

bats "$SCRIPT_DIR"
