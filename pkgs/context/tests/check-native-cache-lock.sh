#!/usr/bin/env bash
# End-to-end check against a built NixOS ConTeXt wrapper.
set -euo pipefail

context="${1:?Usage: check-native-cache-lock.sh path/to/context}"
context="$(readlink -f "$context")"
init="$(dirname "$context")/context-init-cache"
test -x "$init"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"
export TEXMFCACHE="$work/cache"
mkdir -p "$HOME" "$work/a" "$work/b" "$work/c"
for id in a b c; do
  printf '\\starttext Cache regression test \\stoptext\n' > "$work/$id/$id.tex"
done

# Both documents share a brand-new cache; only one initializer may run.
( cd "$work/a"; "$context" --once a.tex ) > "$work/a.log" 2>&1 &
pid_a=$!
( cd "$work/b"; "$context" --once b.tex ) > "$work/b.log" 2>&1 &
pid_b=$!
wait "$pid_a" || { cat "$work/a.log" >&2; exit 1; }
wait "$pid_b" || { cat "$work/b.log" >&2; exit 1; }
test -s "$work/a/a.pdf"
test -s "$work/b/b.pdf"
num_init="$(grep -Fh 'Initializing ConTeXt cache in ' "$work/a.log" "$work/b.log" | wc -l | tr -d ' ')"
if [ "$num_init" != 1 ]; then
  echo "Expected one cache initialization, observed $num_init" >&2
  cat "$work/a.log" "$work/b.log" >&2
  exit 1
fi

after_first="$(find "$TEXMFCACHE" -maxdepth 1 -name '.context-ready-*' -type f | wc -l | tr -d ' ')"
test "$after_first" = 1

# Reusing the cache must not regenerate the database or formats.
( cd "$work/c"; "$context" --once c.tex ) > "$work/c.log" 2>&1 || {
  cat "$work/c.log" >&2; exit 1;
}
test -s "$work/c/c.pdf"
if grep -Fq 'Initializing ConTeXt cache in ' "$work/c.log"; then
  echo 'Cache was unnecessarily initialized again' >&2
  exit 1
fi

# A forced rebuild is allowed and publishes a marker only on success.
"$init" --force > "$work/force.log" 2>&1 || {
  cat "$work/force.log" >&2; exit 1;
}
test "$(find "$TEXMFCACHE" -maxdepth 1 -name '.context-ready-*' -type f | wc -l | tr -d ' ')" = 1

# Initialization failure must not publish a successful marker.
# A regular file is deliberately used as TEXMFCACHE to trigger a failure.
: > "$work/not-a-directory"
if TEXMFCACHE="$work/not-a-directory" "$init" --force > "$work/fail.log" 2>&1; then
  echo 'Expected cache initialization with invalid TEXMFCACHE to fail' >&2
  exit 1
fi

echo 'OK: native cache lock (parallel start, reuse, force, failure)'
