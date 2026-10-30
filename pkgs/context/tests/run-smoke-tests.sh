#!/usr/bin/env bash
# Package smoke tests only, not the independent typographic regression suite.
set -euo pipefail
launcher="$(readlink -f "${1:?Usage: run-smoke-tests.sh launcher workdir test...}")"
work="${2:?Missing work directory}"
shift 2
[ "$#" -gt 0 ] || { echo 'No smoke tests selected' >&2; exit 2; }
fixtures="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$work"
work="$(cd "$work" && pwd)"
for name in "$@"; do
  case "$name" in smoke|filter|vim) ;; *) echo "Unknown smoke test: $name" >&2; exit 2 ;; esac
  # Refuse reused directories: filter must create fresh temporary files.
  mkdir "$work/$name"
  cp "$fixtures/$name.tex" "$work/$name/$name.tex"
  (
    cd "$work/$name"
    "$launcher" --once "$name.tex" > build.log 2>&1 || {
      cat build.log >&2; exit 1;
    }
    test -s "$name.pdf" || { echo "Missing or empty PDF for $name" >&2; exit 1; }
    if [ "$name" = filter ]; then
      grep -Fq 'The external filter created its temporary files.' filter-temp-copy.tex || {
        echo 'The external copy filter did not produce its output' >&2; exit 1;
      }
    fi
    if [ "$name" = vim ]; then
      grep -Fq '\SYN[' vim-temp-PYTHON-0.vimout || {
        echo 'Vim returned no ConTeXt highlighting tokens' >&2; exit 1;
      }
    fi
  )
done
