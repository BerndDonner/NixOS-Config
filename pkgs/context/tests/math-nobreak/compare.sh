#!/usr/bin/env bash
set -euo pipefail

# Usage: ./compare.sh /absolute/path/to/unpatched/context /absolute/path/to/patched/context [output-dir]
if (( $# < 2 || $# > 3 )); then
  echo "Usage: $0 UNPATCHED_CONTEXT PATCHED_CONTEXT [OUTPUT_DIR]" >&2
  exit 2
fi
for exe in pdftotext python3 realpath; do
  command -v "$exe" >/dev/null || { echo "Missing command: $exe" >&2; exit 2; }
done
unpatched=$(realpath "$1")
patched=$(realpath "$2")
[[ -x "$unpatched" && -x "$patched" ]] || { echo 'Context executables not found' >&2; exit 2; }
outdir=${3:-$(mktemp -d "${TMPDIR:-/tmp}/math-nobreak-XXXXXX")}
mkdir -p "$outdir"
outdir=$(realpath "$outdir")
scripts_dir=$(cd "$(dirname "$0")" && pwd)

for version in before after; do
  mkdir -p "$outdir/$version"
  cp "$scripts_dir/cases.tex" "$outdir/$version/cases.tex"
  if [[ $version = before ]]; then engine=$unpatched; else engine=$patched; fi
  ( cd "$outdir/$version"; export TEXMFCACHE="$outdir/cache-$version"; "$engine" --once cases.tex > build.log 2>&1 ) || {
    tail -80 "$outdir/$version/build.log" >&2
    exit 1
  }
  test -s "$outdir/$version/cases.pdf" || { echo "No PDF from $version" >&2; exit 1; }
  pdftotext -layout "$outdir/$version/cases.pdf" "$outdir/$version/cases.txt"
done

python3 - "$outdir" <<'PYCODE'
from pathlib import Path
import sys
root = Path(sys.argv[1]); before = (root/'before/cases.txt').read_text(); after = (root/'after/cases.txt').read_text()
def pages(text):
    return [p for p in text.split('\f') if p.strip()]
def body(page):
    lines = page.splitlines()
    starts = [i for i,l in enumerate(lines) if 'Das digitale Geraet' in l]
    if len(starts)!=1: raise ValueError(f'Cannot find body: {page!r}')
    return '\n'.join(lines[starts[0]:]).strip()
bef=[body(p) for p in pages(before)]; aft=[body(p) for p in pages(after)]
if len(bef)!=12 or len(aft)!=12:
    raise SystemExit(f'FAIL: Expected 12 pages, got before={len(bef)} after={len(aft)}')
changes=[]
for idx,(b,a) in enumerate(zip(bef,aft),start=1):
    if b!=a: changes.append(idx)
    print(f"C{idx:02}: {'CHANGED' if a != b else 'unchanged'}")
# C01 and C06 alone should change, to match their explicit-penalty counterparts.
if changes != [1,6]:
    raise SystemExit(f'FAIL: Unexpected line-layout changes: {changes}; expected only C01 and C06')
if aft[0] != aft[1]:
    raise SystemExit('FAIL: C01 (~) differs from C02 (explicit penalty)')
if aft[5] != aft[7]:
    raise SystemExit('FAIL: C06 (mathsurround + ~) differs from C08 (explicit penalty)')
print('PASS: protected spaces after math fixed; all 10 control cases unchanged.')
print('Artifacts:', root)
PYCODE
