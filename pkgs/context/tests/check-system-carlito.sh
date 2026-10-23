#!/bin/sh
# Host integration test; run on NixOS, NOT in the Nix build sandbox.
set -eu

context_bin=${1:-./result-context/bin/context}
if [ ! -f "$context_bin" ]; then
  echo "ConTeXt executable not found: $context_bin" >&2
  exit 1
fi
context_bin=$(readlink -f "$context_bin")

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

# On NixOS the package wrapper must supply OSFONTDIR itself. The override
# exists only to exercise the same test with a portable ConTeXt installation.
if [ -n "${CARLITO_TEST_FONTDIR:-}" ]; then
  font_dir=${CARLITO_TEST_FONTDIR%/}
  export OSFONTDIR="$font_dir"
else
  unset OSFONTDIR
  font_dir=
  for dir in /run/current-system/sw/share/X11/fonts /run/current-system/sw/share/fonts; do
    if [ -f "$dir/Carlito-Regular.ttf" ] && [ -f "$dir/Carlito-Bold.ttf" ]; then
      font_dir=$dir
      break
    fi
  done
  if [ -z "$font_dir" ]; then
    echo 'Carlito Regular/Bold not found under the NixOS system font paths' >&2
    exit 1
  fi
fi

for face in Regular Bold; do
  if [ ! -f "$font_dir/Carlito-$face.ttf" ]; then
    echo "Missing system font: $font_dir/Carlito-$face.ttf" >&2
    exit 1
  fi
done

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir -p "$test_dir/home" "$test_dir/cache" "$test_dir/work"
cp "$script_dir/system-carlito.tex" "$test_dir/work/carlito.tex"

(
  cd "$test_dir/work"
  HOME="$test_dir/home" TEXMFCACHE="$test_dir/cache" \
    "$context_bin" --once carlito.tex > "$test_dir/context.log" 2>&1
) || {
  cat "$test_dir/context.log" >&2
  exit 1
}

if [ ! -s "$test_dir/work/carlito.pdf" ]; then
  echo 'ConTeXt did not produce a Carlito test PDF' >&2
  exit 1
fi

# Verify the exact files, not merely that the font family was resolved or a
# fallback was selected. The font log uses this form in LMTX 2026.10.23.
for face in Regular Bold; do
  if ! grep -Fq "loading '$font_dir/Carlito-$face.ttf'" "$test_dir/context.log"; then
    echo "ConTeXt did not load $font_dir/Carlito-$face.ttf" >&2
    grep -i 'carlito\|fallback\|unknown font' "$test_dir/context.log" >&2 || true
    exit 1
  fi
done

echo "OK: Carlito Regular and Bold loaded from $font_dir"
echo 'OK: ConTeXt produced the Carlito test PDF'
