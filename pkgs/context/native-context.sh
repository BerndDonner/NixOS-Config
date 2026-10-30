# Build values are shell-quoted before substitution.
LOCAL_VERSION=@localVersion@
PATCH_LABEL=@patchLabel@
if [ -n "$LOCAL_VERSION" ] && [ "$#" -eq 1 ] && [ "$1" = --version ]; then
  printf 'mtx-context | local build: %s (%s)\n' "$LOCAL_VERSION" "$PATCH_LABEL"
fi
CACHE_MARKER="$CACHE_ROOT/.context-ready-@packageId@"

# Only a successful initialization publishes the marker.
if [ ! -f "$CACHE_MARKER" ]; then
  "@out@/bin/context-init-cache" --if-needed
fi
exec "@out@/tex/texmf-linux-64/bin/context" "$@"
