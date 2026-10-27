# Engine-level noautobreak fix — ConTeXt 2026.10.25

This is an experimental regression fix for LuaMetaTeX `texlinebreak.c`, not a ConTeXt macro workaround.

It covers **both** branches in `case end_inline_math`: zero/ignored math skip and nonzero math skip.

## Build and compare (NixOS-Config checkout)

Before applying the repository patch:

```bash
nix build .#context -o result-context-unpatched -L
```

Apply the repository patch (delivered separately):

```bash
git apply --check math-nobreak-nixos.patch
git apply math-nobreak-nixos.patch
nix build .#context -o result-context-patched -L
```

Compare exactly the same TeX source on both **current** versions:

```bash
nix shell nixpkgs#poppler-utils nixpkgs#python3 -c bash \
  pkgs/context/tests/math-nobreak/compare.sh \
  "$PWD/result-context-unpatched/bin/context" \
  "$PWD/result-context-patched/bin/context" \
  "$PWD/math-nobreak-results"
```

This creates two 12-page PDFs, their extracted text and build logs. The script checks that
cases C01 and C06 now match their explicit-penalty reference, and that **all ten other
cases** have exactly unchanged extracted line layout.

The build will fail if the pinned LuaMetaTeX source does not accept the C patch.
To remove the experimental fix, revert the repository patch / use the unpatched result.
Do not update your system configuration before examining the PDFs and diffs.

## Test matrix

| ID | Case | Expected change |
|---|---|---|
| C01 | Math followed by `~` | Yes, must protect break |
| C02 | Math followed by explicit `\nonbreakablespace` | No |
| C03 | Math followed by ordinary space | No; break remains possible |
| C04 | Text followed by `~` | No |
| C05 | Text followed by ordinary space | No |
| C06 | Math followed by `~`, `\mathsurround=3pt` | Yes |
| C07 | Math followed by ordinary space, `\mathsurround=3pt` | No |
| C08 | Math followed by explicit nonbreakable space, `\mathsurround=3pt` | No |
| C09 | Math followed by `\penalty10000` | No |
| C10 | Math followed by `\penalty0` | No |
| C11 | Math followed by thin space | No |
| C12 | Math followed by comma and ordinary space | No |

PDF text comparison is only one regression gate. Visual comparison is recommended before any upstream proposal.
