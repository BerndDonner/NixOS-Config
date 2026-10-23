#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READY="$(cd "$HERE/../../.." && pwd)"
exec "$READY/glibc/ld-linux-x86-64.so.2" \
  --library-path "$READY/glibc" \
  "$HERE/luametatex.bin" "$@"
