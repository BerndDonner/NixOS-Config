#!@runtimeShell@
set -euo pipefail

# Per-user cache directory; ConTeXt will append "luametatex-cache/context/<hash>".
if [ -z "${TEXMFCACHE:-}" ]; then
  TEXMFCACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
  export TEXMFCACHE
fi

# System + user font search paths (only if not set by user)
if [ -z "${OSFONTDIR:-}" ]; then
  OSFONTDIR="/run/current-system/sw/share/X11/fonts"
  OSFONTDIR="$OSFONTDIR:/run/current-system/sw/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.local/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.fonts"
  export OSFONTDIR
fi

CACHE_ROOT="${TEXMFCACHE%/}"
