#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READY="$(cd "$HERE/../../.." && pwd)"

# ConTeXt's native entrypoints are engine aliases named mtxrun and context.
# Keep that program name when launching the Nix-built ELF through our bundled
# glibc loader: LuaMetaTeX selects mtxrun.lmt / context.lmt via argv[0].
NAME="$(basename "$0")"
case "$NAME" in
  luametatex|mtxrun|context) ;;
  *) echo "Unknown LuaMetaTeX entrypoint: $NAME" >&2; exit 2 ;;
esac
exec "$READY/glibc/ld-linux-x86-64.so.2" \
  --library-path "$READY/glibc" \
  --argv0 "$HERE/$NAME" \
  "$HERE/luametatex.bin" "$@"
