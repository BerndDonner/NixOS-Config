#!/usr/bin/env bash
# Fill missing distribution data, preserving downloaded data and user state.
set -euo pipefail
source_dir="${1:?Usage: init-state.sh source-directory state-directory}"
state_dir="${2:?Missing state directory}"
test -d "$source_dir/data"
install -d -m 0750 "$state_dir" "$state_dir/data"
temporary=''
trap 'if [ -n "$temporary" ]; then rm -f -- "$temporary"; fi' EXIT
while IFS= read -r -d '' source_file; do
  relative="${source_file#"$source_dir/"}"
  destination="$state_dir/$relative"
  # Existing files (including daemon-updated data) belong to the running app.
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    continue
  fi
  install -d -m 0750 "$(dirname "$destination")"
  temporary="$(mktemp "$state_dir/.seed.XXXXXXXX")"
  install -m 0640 "$source_file" "$temporary"
  # Publish a complete file only; an interrupted copy is retried next start.
  # No overwrite if another initializer has already supplied the destination.
  mv -n -- "$temporary" "$destination"
  rm -f -- "$temporary"
  temporary=''
done < <(find "$source_dir/data" -type f -print0)
