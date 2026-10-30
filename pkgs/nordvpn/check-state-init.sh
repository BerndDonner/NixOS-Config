#!/usr/bin/env bash
# State initialization is testable without root, systemd, networking or Nix.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/init-state.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/source/data/nested" "$work/state"
printf original > "$work/source/data/servers.dat"
printf hidden > "$work/source/data/.hidden"
printf nested > "$work/source/data/nested/asset"
# A nonempty, partially initialized state must still receive missing files.
printf credentials > "$work/state/settings.dat"
printf updated > "$work/state/data-placeholder"
bash "$script" "$work/source" "$work/state"
cmp "$work/source/data/servers.dat" "$work/state/data/servers.dat"
cmp "$work/source/data/.hidden" "$work/state/data/.hidden"
cmp "$work/source/data/nested/asset" "$work/state/data/nested/asset"
test "$(stat -c %a "$work/state/data/servers.dat")" = 640
printf downloaded > "$work/state/data/servers.dat"
rm "$work/state/data/nested/asset"
bash "$script" "$work/source" "$work/state"
test "$(cat "$work/state/data/servers.dat")" = downloaded
test "$(cat "$work/state/settings.dat")" = credentials
cmp "$work/source/data/nested/asset" "$work/state/data/nested/asset"
test -z "$(find "$work/state" -name '.seed.*' -print)"
if bash "$script" "$work/missing" "$work/state"; then
  echo 'Missing seed data should fail' >&2; exit 1
fi
echo 'OK: state seeding repairs partial state and preserves existing data'
