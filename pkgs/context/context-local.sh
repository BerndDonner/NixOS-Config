#!/usr/bin/env bash
# Portable ConTeXt launcher using the official LMTX .lmt entrypoints.
set -euo pipefail

# Expose the local patch revision without modifying ConTeXt's internal
# \contextversion or invalidating its format compatibility checks.
if [ "$#" -eq 1 ] && [ "$1" = "--version" ]; then
  printf '%s\n' 'mtx-context | local build: @LOCAL_BUILD_VERSION@ (@PATCH_LABEL@)'
fi

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
LOCK_DIR="$TEXMFCACHE/.context-init-@BUNDLE_HASH@.lock"

initialize_cache_if_needed() (
  # Use only POSIX-style filesystem operations plus Bash: no flock binary
  # or additional shared library is required in the portable sandbox.
  mkdir -p "$TEXMFCACHE"
  attempts=0
  until mkdir "$LOCK_DIR" 2>/dev/null; do
    # The winner may have finished while we were waiting.
    if [ -f "$MARKER" ]; then
      exit 0
    fi
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 1500 ]; then
      echo "Timed out waiting for ConTeXt cache lock: $LOCK_DIR" >&2
      echo "If its owner was killed, remove this stale lock directory." >&2
      exit 1
    fi
    sleep 0.2
  done

  # This subshell owns the lock. Even on ordinary failures the lock is
  # removed; SIGKILL/power loss can leave a stale directory (documented).
  trap 'rmdir "$LOCK_DIR"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  # Another caller may have initialized the cache before we got the lock.
  if [ -f "$MARKER" ]; then
    exit 0
  fi

  "$BIN/mtxrun" --generate
  "$BIN/mtxrun" --script fonts --reload
  "$BIN/context" --make

  marker_tmp="$MARKER.tmp.$$"
  trap 'rm -f "$marker_tmp"; rmdir "$LOCK_DIR"' EXIT
  printf '%s\n' '@BUNDLE_HASH@' > "$marker_tmp"
  mv -f "$marker_tmp" "$MARKER"
)

if [ ! -f "$MARKER" ]; then
  initialize_cache_if_needed
fi
exec "$BIN/context" "$@"
