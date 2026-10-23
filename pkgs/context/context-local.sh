#!/usr/bin/env bash
# Portable ConTeXt launcher using the official LMTX .lmt entrypoints.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/tex/texmf-linux-64/bin"

# Writable cache, separate for each immutable bundled ConTeXt tree.
export TEXMFCACHE="${TEXMFCACHE:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/context-lmtx-@BUNDLE_HASH@}"
export TEXROOT="$HERE/tex"
export SELFAUTOPARENT="$HERE/tex"

# Preserve caller-supplied fonts; use portable system/bundled paths otherwise.
if [ -z "${OSFONTDIR:-}" ]; then
  export OSFONTDIR="$HERE/tex/texmf/fonts:${HOME:-/tmp}/.local/share/fonts:/usr/share/fonts"
fi

# A successful format build is the cache readiness criterion, NOT merely the
# existence of the luametatex-cache directory (which can be partial/stale).
MARKER="$TEXMFCACHE/.context-ready-@BUNDLE_HASH@"
if [ ! -f "$MARKER" ]; then
  mkdir -p "$TEXMFCACHE"
  "$BIN/mtxrun" --generate
  "$BIN/mtxrun" --script fonts --reload
  "$BIN/context" --make
  touch "$MARKER"
fi

exec "$BIN/context" "$@"
