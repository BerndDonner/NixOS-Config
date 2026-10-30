# ConTeXt LMTX: package and host tests

This directory contains **package-integrity tests**, not the general ConTeXt
regression suite. The independent `context-testsuite` repository owns the
12 basic and 76 extended Math/Glue/Penalty cases, their expected behavior,
and the PDF comparison tools. None of those tests is run by `nix build` or
`nix flake check` in this repository.

## Which tests run when?

| Test | File / implementation | Trigger | Purpose |
| --- | --- | --- | --- |
| Basic PDF | `smoke.tex` | Building any of the three engine versions (also the patched sandbox) | Bundled fonts, `\unit`, MetaPost, output PDF |
| External filter | `filter.tex` | Same builds for modern `.lmt` runners | External filter really writes its temporary output |
| Vim highlighting | `vim.tex` | Same builds for modern `.lmt` runners | Generated `\SYN[` highlighting tokens, not only a PDF |
| Native cache lock | `check-native-cache-lock.sh` | Building local ConTeXt packages | Concurrent starts, cache reuse, force rebuild, invalid cache directory |
| Portable cache lock | `check-portable-cache-lock.sh` | Building `.#context-sandbox-patched` | Locking and failure recovery using fake engine entrypoints |
| **Host Carlito** | **`check-system-carlito.sh`, `system-carlito.tex`** | **Manual; never part of a Nix build** | **Find host system fonts via the ConTeXt wrapper** |

`luametatex.nix` and `sandbox.nix` run their respective tests in isolated
build working directories. The historical `.lua`-runner variant runs only
`smoke.tex`, because the modern filter/Vim integration is not a historical
compatibility target. Vim is a build-time tool: it is not packaged into the
portable archive and must be on `PATH` if a document uses Vim highlighting at
runtime. Merely producing a PDF does not prove that the filter/Vim tests
succeeded: both inspect the generated intermediate files.

The external filter source is pinned at `ca120d8`, which contains the
upstream `file.canbewritten` correction in `t-filter.mkxl`. No local filter
module patch is applied. The functional test uses newly created files and
will fail the package build if that fix does not work.

## Host font regression: Carlito (MANUAL)

**This test is intentionally not automatic.** A derivation's Nix sandbox
cannot inspect fonts installed on the running host. From the root of
`NixOS-Config`, on `kitty` or `tracy`:

```bash
nix build .#context -o result-context -L
pkgs/context/tests/check-system-carlito.sh \
  ./result-context/bin/context
```

To test the new upstream or historical reference instead, use
`nix build .#context-upstream` or `nix build .#context-2024` and pass the
corresponding `result-*/bin/context` path.

Requirements and expectations:

- Carlito **Regular** and **Bold** must already be installed system-wide under
  `/run/current-system/sw/share/X11/fonts` or
  `/run/current-system/sw/share/fonts` (with the filenames expected by the
  script). The test does not install the fonts.
- The script deliberately **unsets `OSFONTDIR`**, so the installed ConTeXt
  wrapper must set its default NixOS font paths.
- It creates temporary home/cache/work directories, compiles
  `system-carlito.tex` and verifies the log loaded *both exact host font
  files*, rather than bundled fonts or a fallback.
- It exits nonzero if the fonts cannot be found or loaded. The script does
  not require any ConTeXt package to be installed globally; the `nix build`
  output is passed as an argument.

For portable troubleshooting on another host, override the search location:

```bash
CARLITO_TEST_FONTDIR=/path/to/fonts \
  pkgs/context/tests/check-system-carlito.sh /path/to/context-local.sh
```

**Caution:** This checks explicit font loading, **not** the NixOS wrapper's
default `OSFONTDIR` behavior. This override is never used in the standard
host test.

## Cache synchronization (manually repeatable)

The native test runs during the local package build and can be repeated with:

```bash
bash pkgs/context/tests/check-native-cache-lock.sh \
  ./result-context/bin/context
```

It checks two simultaneous initializations, reuse, forced regeneration and
clean failure for an unusable cache directory.

The portable cache test runs during the portable bundle build and can also
be run without ConTeXt installed:

```bash
bash pkgs/context/tests/check-portable-cache-lock.sh \
  pkgs/context/context-local.sh
```

Its fake engine entrypoints exercise concurrent starts, failure and recovery.
The real portable bundle additionally runs its own PDF/filter/Vim smoke tests.

## Behavioral and visual regression tests (separate repository)

The independent `context-testsuite` repository contains the migrated
Math/Glue/Penalty tests and the PDF comparison CLI. To run it, build the two
variants here and pass their executable paths **directly**, without
exporters, manifests, or a dependency between the repositories:

```bash
# In NixOS-Config:
nix build .#context-upstream -o result-context-upstream -L
nix build .#context -o result-context -L

# In context-testsuite (after `nix develop` there):
context-testsuite run \
  --baseline ../NixOS-Config/result-context-upstream/bin/context \
  --context ../NixOS-Config/result-context/bin/context \
  --suite all \
  --output results/lmtx-patch-validation
```

Adjust the relative paths to suit where you keep the two clones. This is an
explicit manual run; neither `NixOS-Config` nor `unterrichts-texte` imports
`context-testsuite`. Run `python -m pytest -q` in the testsuite repository to
check its Python implementation independently of a real ConTeXt engine.
