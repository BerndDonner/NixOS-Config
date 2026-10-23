#!/usr/bin/env bash
# Standalone regression test of the portable launcher (no LuaMetaTeX needed).
# Mock engine entrypoints make races and failures deterministic.
set -euo pipefail

launcher="${1:?Usage: check-portable-cache-lock.sh path/to/context-local.sh}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
bundle="$work/bundle"
bin="$bundle/tex/texmf-linux-64/bin"
mkdir -p "$bin"
sed 's/@BUNDLE_HASH@/test-1234/g' "$launcher" > "$bundle/context-local.sh"
# The bundle must retain /usr/bin/env for portable use, but the *test copy*
# runs inside a Nix builder without /usr/bin/env. Do not modify the archive.
sed -i "1c#!$(command -v bash)" "$bundle/context-local.sh"
chmod +x "$bundle/context-local.sh"

cat > "$bin/mtxrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "mtxrun:$*" >> "$CACHE_TEST_LOG"
if [ "${CACHE_TEST_FAIL_STEP:-}" = generate ] && [ "${1:-}" = --generate ]; then
  exit 17
fi
if [ "${CACHE_TEST_FAIL_STEP:-}" = fonts ] && [ "${1:-}" = --script ]; then
  exit 18
fi
# Long enough that multiple simultaneous callers hit the lock.
sleep 0.2
SH
cat > "$bin/context" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "context:$*" >> "$CACHE_TEST_LOG"
if [ "${CACHE_TEST_FAIL_STEP:-}" = make ] && [ "${1:-}" = --make ]; then
  exit 19
fi
if [ "${1:-}" = --make ]; then sleep 0.2; fi
SH
# The Nix builder has no /usr/bin/env; mocks use its Bash directly.
sed -i "1c#!$(command -v bash)" "$bin/mtxrun" "$bin/context"
chmod +x "$bin/mtxrun" "$bin/context"

export HOME="$work/home"
export TEXMFCACHE="$work/cache"
export CACHE_TEST_LOG="$work/commands.log"
mkdir -p "$HOME"

# Four simultaneous first invocations must initialize exactly once.
for i in 1 2 3 4; do
  "$bundle/context-local.sh" --once "test-$i.tex" > "$work/job-$i.log" 2>&1 &
  jobs+=("$!")
done
for pid in "${jobs[@]}"; do
  if ! wait "$pid"; then
    echo 'Portable cache concurrency test failed. Worker logs:' >&2
    for log in "$work"/job-*.log; do
      echo "--- $log ---" >&2
      cat "$log" >&2
    done
    exit 1
  fi
done

count() { grep -Fxc "$1" "$CACHE_TEST_LOG" || true; }
test "$(count 'mtxrun:--generate')" = 1
test "$(count 'mtxrun:--script fonts --reload')" = 1
test "$(count 'context:--make')" = 1
test "$(grep -c '^context:--once test-' "$CACHE_TEST_LOG")" = 4
test -f "$TEXMFCACHE/.context-ready-test-1234"
test ! -d "$TEXMFCACHE/.context-init-test-1234.lock"

# Reuse must not reinitialize anything.
"$bundle/context-local.sh" --once reused.tex > "$work/reuse.log" 2>&1
test "$(count 'mtxrun:--generate')" = 1
test "$(count 'context:--make')" = 1

# Failure after acquiring the lock must leave no marker and release the lock.
export TEXMFCACHE="$work/failing-cache"
export CACHE_TEST_FAIL_STEP=make
if "$bundle/context-local.sh" --once fail.tex > "$work/fail.log" 2>&1; then
  echo 'Expected mock format generation to fail' >&2
  exit 1
fi
test ! -e "$TEXMFCACHE/.context-ready-test-1234"
test ! -d "$TEXMFCACHE/.context-init-test-1234.lock"

# A later call recovers without manual cleanup.
unset CACHE_TEST_FAIL_STEP
"$bundle/context-local.sh" --once recovery.tex > "$work/recovery.log" 2>&1
test -f "$TEXMFCACHE/.context-ready-test-1234"
test ! -d "$TEXMFCACHE/.context-init-test-1234.lock"

echo 'OK: portable cache lock (parallel start, reuse, failure, recovery)'
