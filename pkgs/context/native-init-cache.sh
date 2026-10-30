MTXRUN="@out@/tex/texmf-linux-64/bin/mtxrun"
CONTEXT="@out@/tex/texmf-linux-64/bin/context"
FLOCK="@utilLinux@/bin/flock"
CACHE_MARKER="$CACHE_ROOT/.context-ready-@packageId@"
LOCK_FILE="$CACHE_ROOT/.context-init-@packageId@.lock"

# Explicit invocation without arguments still forces a rebuild.
# The context wrapper uses --if-needed and rechecks under the lock.
mode=--force
if [ "$#" -gt 0 ]; then
  if [ "$#" -ne 1 ]; then
    echo 'Usage: context-init-cache [--force|--if-needed]' >&2
    exit 2
  fi
  mode="$1"
fi
case "$mode" in
  --force|--if-needed) ;;
  *) echo 'Usage: context-init-cache [--force|--if-needed]' >&2; exit 2 ;;
esac

mkdir -p "$CACHE_ROOT"
# An open file descriptor holds a kernel-managed lock. It is released on
# exit, including when initialization fails or the process is killed.
exec 9>"$LOCK_FILE"
"$FLOCK" -x 9

if [ "$mode" = --if-needed ] && [ -f "$CACHE_MARKER" ]; then
  exit 0
fi

# Invalidate even a formerly valid marker before an explicit rebuild.
rm -f "$CACHE_MARKER"
echo "Initializing ConTeXt cache in $CACHE_ROOT/luametatex-cache ..." >&2
"$MTXRUN" --generate
"$MTXRUN" --script fonts --reload
"$CONTEXT" --make

# Publish only a completely generated cache. A crash while writing the
# temporary file cannot leave a successful-looking readiness marker.
marker_tmp="$CACHE_MARKER.tmp.$$"
trap 'rm -f "$marker_tmp"' EXIT
printf '%s\n' '@packageId@' > "$marker_tmp"
mv -f "$marker_tmp" "$CACHE_MARKER"
trap - EXIT
