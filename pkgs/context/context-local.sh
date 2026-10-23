#!/usr/bin/env bash
# Portable ConTeXt launcher. This is NOT the NixOS launcher.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/tex/texmf-linux-64/bin"

# Cache must be writable even when the archive was extracted read-only.
export TEXMFCACHE="${TEXMFCACHE:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/context-lmtx-@BUNDLE_HASH@}"
export TEXROOT="$HERE/tex"
export SELFAUTOPARENT="$HERE/tex"

# Allow an explicit caller-supplied OSFONTDIR; supply bundled fonts by default.
# Unlike the NixOS wrapper, this cannot search /run/current-system/sw.
if [ -z "${OSFONTDIR:-}" ]; then
  export OSFONTDIR="$HERE/tex/texmf/fonts:${HOME:-/tmp}/.local/share/fonts:/usr/share/fonts"
fi

CACHE_MARKER="$TEXMFCACHE/luametatex-cache"
if [ ! -d "$CACHE_MARKER" ]; then
  mkdir -p "$TEXMFCACHE"
  "$BIN/luametatex" --luaonly "$BIN/mtxrun.lua" --generate
fi

exec "$BIN/luametatex" --luaonly "$BIN/mtxrun.lua" --script context "$@"
