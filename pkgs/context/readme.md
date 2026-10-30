# ConTeXt LMTX – shared NixOS / portable sandbox builds

## Versions and patch policy

Exactly three engine versions are available. **`context` is our patched
productive default**, exposed both as `packages.context` and as
`pkgs.contextLmtx` in the public `overlays.context`. Consumer dev shells must
select only one engine package at a time.

| Output | Revision | Engine patch |
| --- | --- | --- |
| `.#context` | `5751e39641a5` (25 Oct 2026) | `luametatex-math-glue-noautobreak.patch` **enabled** |
| `.#context-2024` | `0d2ec448a05c` (1 Nov 2024) | none; historical baseline |
| `.#context-upstream` | `445076e571b5` (29 Oct 2026) | none; updated upstream baseline |
| `.#context-sandbox-patched` | **same derivation as `.#context`** | portable `.tar.xz` archive |
| `.#context-docs` | **same derivation as `.#context`** | documentation archive |

All other former variant and sandbox outputs have been removed, not aliased.
The older 2026.10.25 upstream build is deliberately **not** exported.

The default has Nix package version `2026.10.25-p1`. Its `context --version`
prints `local build: 2026.10.25-p1 (math-glue-noautobreak)` in addition to the
original ConTeXt version `2026.10.25 20:06`. The internal
`\contextversion` is deliberately **not** edited (ConTeXt uses it for format
handling). The portable `context-local.sh --version` carries the same marker.
The reference versions use their original upstream version information.

The LuaMetaTeX patch corrects implicit line breaks after inline mathematics
followed by `noautobreak` glue while preserving forced breaks. It is essential
to our productive package; do not delete it as if it were an experiment.
The upstream comparison build remains **unpatched**, even if upstream later
changes or replaces its own penalty handling.

The derivation in `luametatex.nix` still accepts an **ordered** `enginePatches`
list (using `--fuzz=0`), as well as optional `localVersion` and `patchLabel`
arguments. `mkContextPackage` in the root flake accepts any revision and
patch list. Future proposals can therefore be built independently without
reintroducing a global patch-variant registry or accidentally combining
incompatible patches. New patches must be tracked by Git before Nix can see
them. The historical version automatically selects the old `.lua` runner;
modern versions use `.lmt`. The 2024 build runs only the basic smoke document.

### Source and filter pins

All sources are declared in the **root** `flake.nix` and locked in the root
`flake.lock`:

- `context-src`: productive 2026-10-25 source, currently locked at `5751e396`;
  keep this fixed until intentionally moving the productive patch to a new
  upstream release.
- `context-2024-src`: fixed historical revision `0d2ec448`.
- `context-upstream-src`: fixed comparison revision `445076e5`.
- `filter-src`: fixed `adityam/filter` revision `ca120d8` (both `filter` and
  Vim integration).

The pins are already recorded in `flake.lock`. Script-only packaging changes
require no lock update. When deliberately adding or changing a source input,
run `nix flake lock` and review `git diff -- flake.lock` before committing.

The filter upstream module now uses `file.canbewritten` in `t-filter.mkxl`.
The main ConTeXt source already handles empty `pathpart` in
`file.canbewritten`. Therefore the old local `filter-lmtx-writable.patch`
was removed. The native and portable packages **still execute** the real
filter and Vim integration tests. Do not adopt the update if they fail.

ConTeXt's Git tree omits the bootstrap/font `texmf.zip`; it remains pinned
by its existing fixed-output hash in `luametatex.nix`. It is shared across
these builds. This package does not install ConTeXt globally on either host.

### Build and verify

```bash
# Include new local helpers in the Git source seen by Nix.
git add pkgs/context

nix build .#context -o result-context -L
nix build .#context-2024 -o result-context-2024 -L
nix build .#context-upstream -o result-context-upstream -L
./result-context/bin/context --version

nix build .#context-sandbox-patched -o result-sandbox-patched -L
nix develop .#context -c python3 pkgs/context/verify-bundle.py \
  result-context result-sandbox-patched

nix build .#context-docs -o result-docs -L
nix develop .#context -c python3 pkgs/context/verify-docs.py \
  result-context result-docs
```

The `devShells.context` output in this repository is the small Python-only
verification shell. It is **not** a ConTeXt development environment.
`lib.mkContextDevShell` puts exactly the `contextPackage` supplied by a
consumer onto `PATH`. Consumers such as `unterrichts-texte` should now use
`nixos-config.packages.${system}.context`, not the deleted
`context-patched` name. Update and commit the consumer's own locked
`nixos-config` input after validating and publishing this patch.

Package builds check startup, cache locking, an actual PDF, and (on modern
runners) external filter and Vim functionality. They do **not** guarantee
correct Math/Glue/Penalty typography. That belongs to the independent
`context-testsuite` repository. See [`tests/README.md`](tests/README.md).

To investigate changes in an upstream release, change only the exact
`context-upstream-src` URL to a new Git commit and lock that input. Updating
`context-src` separately also requires reviewing the local engine patch and
its version marker: do not silently move the production source to a new
commit. Never update all flake inputs to test just ConTeXt.

### Manual host-font regression

The Carlito host test cannot run inside the Nix builder sandbox. Run it on
`kitty` or `tracy`, where the real system fonts are visible:

```bash
pkgs/context/tests/check-system-carlito.sh ./result-context/bin/context
```

It checks Carlito Regular/Bold from the host system font directories.

## Packaging scripts

- `native-environment.sh`, `native-context.sh`, `native-init-cache.sh` are
  build templates. Nix assembles them into standalone launchers and replaces
  explicit placeholders; unresolved placeholders fail the build.
- `context-local.sh` and `portable-engine.sh` remain portable launchers.
  Native `flock` and portable directory locking stay separate.
- `manifest_common.py` owns checksum framing and the distinct runtime/docs
  pruning policies. `make-bundle-manifest.py` and `make-docs-manifest.py`
  write manifests; `verify-bundle.py` and `verify-docs.py` validate archives.
  Build commands reference the containing directory so regular Python imports
  find their sibling module in the Nix store.
- `tests/run-smoke-tests.sh` runs the shared PDF/filter/Vim checks in fresh
  directories. `--once` is restricted to these package smoke checks and cache
  tests; it is not a setting for the independent regression suite.

The native package includes `share/context/build-info.json` with full source
revision, Nix package version and patch label. Both archive verifiers compare
revision and version to this metadata, never deriving a commit from `-p1`
or a store directory name. Rebuild the native package before using these
verifiers: older outputs do not have that file. Archive schemas and checksum
semantics are unchanged; neither archive needs an extra metadata file.

Run the fast packaging tests without building an engine:

```bash
nix develop .#context -c python3 -m unittest discover \
  -s pkgs/context/tests -p 'test_*.py' -v
```

They cover fixed checksums from the former implementations and actual
manifest generation/archive verification, including altered provenance,
changed contents and missing files. These fixture tests do not replace the
real Nix builds and their ConTeXt integration checks.

## Cache synchronization

The local `context` wrapper initializes its per-user cache on demand. The
`context-init-cache` helper now serializes initialization with an advisory
**kernel `flock`** on a lock file in `TEXMFCACHE`. It checks the readiness
marker again *after* taking the lock, so simultaneous first starts run
`mtxrun --generate`, `mtxrun --script fonts --reload` and `context --make`
only once. The lock is automatically released on process exit, including
failed initialization. The readiness marker is published with an atomic
rename only after all three steps succeed.

To rebuild deliberately (e.g. after changing system font configuration):

```bash
./result-context/bin/context-init-cache --force
```

An explicit invocation without options also forces initialization, as before.
`--if-needed` is for the `context` wrapper and skips a valid cache. A failed
forced rebuild removes the old ready marker; the next normal `context` call
will retry. Locking protects cache *initialization*, not running documents
against an administrator explicitly forcing a cache rebuild at the same time.

The **portable launcher** uses an atomic `mkdir` lock instead of requiring
`flock` in the target environment. It rechecks the marker after acquiring
the lock, cleans up on normal errors/signals, and gives up after five minutes
rather than hanging forever. Only an abrupt SIGKILL/power loss can leave the
`.context-init-<bundle-hash>.lock` directory behind; after checking no
initializer is active, remove that *directory* manually to recover. The
ready marker is similarly published atomically.

Build-time integration tests now cover simultaneous first starts, reuse of
existing cache state, forced native reinitialization, and error handling.
Portable lock behavior is also verified using a mocked engine so failure
paths can be exercised deterministically.

## Sandbox archive

`nix build .#context-sandbox-patched -o result-sandbox-patched` yields a **regular `.tar.xz`
file**, with the same root layout as the previous
`context-lmtx-ready.tar.xz`. The archive includes:

- exactly the installed LuaMetaTeX engine from `packages.context`;
- all required LMTX runtime files, fonts, `filter` and `vim` modules;
- the ELF loader and the dynamically resolved shared libraries (without Nix);
- `context-local.sh` and `manifest.json` with the source revision, engine
  SHA256, a checksum of the **complete original** TeX tree, and another
  checksum of the **retained portable** TeX tree.

The desktop package stays complete. The portable bundle omits upstream
reference/documentation files under `texmf-context/doc`, legacy `mkii`
directories, and stand-alone `*.mkii` files. It deliberately **keeps `mkiv`**:
LMTX loads many shared Lua files from that directory. The verifier compares
the portable tree against precisely this projection of the desktop tree,
so missing runtime files still fail verification.

Keep `.tar.xz` for now. `context-agent` currently unpacks the payload using
`tar -xJf` in its bootstrap script. Changing to `.tar.zst` requires updating
that script and its bundle transport too; zstd on the host alone is not enough.

## Optional documentation source archive

`nix build .#context-docs -o result-docs` produces a separate **`.tar.xz`
file** from the *same* `pkgs.contextLmtx` derivation as `.#context` and
`.#context-sandbox-patched`. The local NixOS package still has the complete upstream
`texmf-context/doc` directory. Neither the local `installPhase` nor the
runtime sandbox changes.

Inside the archive, `context-lmtx-docs/doc/` preserves the upstream
`doc/context/` structure with source manuals, examples, MkXL/LMTX **and MkIV**
reference material, and associated images/other assets. All `.pdf` files,
legacy `mkii` directories and stand-alone `.mkii` files are omitted. As a
source/reference collection, the archive is **not guaranteed to be
self-contained for compiling every manual**, since some examples may refer to
excluded PDF assets or external libraries.

A `manifest.json` records the pinned ConTeXt revision, package version, the
SHA-256 of the original complete documentation tree and the SHA-256 and file
count of the retained sources. To build and compare against `.#context`:

```bash
git add pkgs/context
nix build .#context-docs -o result-docs --show-trace
nix develop .#context -c python3 \
  pkgs/context/verify-docs.py result-context result-docs
```

The documentation archive is **optional** for `context-agent`: upload it
separately when reference sources are useful. Do not replace the runtime
`context-lmtx-ready.tar.xz` with it. Prefer MkXL material for current LMTX
usage and consult MkIV material only with compatibility checks.

The sandbox builder does **not** fetch, compile or install a second ConTeXt.
It runs three separate regression documents: fonts/units/MetaPost, a real
external copy filter creating new input and output files, and Python code
highlighted by invoking Vim. The copy filter's output and Vim's emitted
`\SYN[` tokens are inspected, so simply loading the modules or
producing an otherwise valid PDF does not pass the test.

Vim is a **build-time dependency** of both Nix derivations for these tests.
Vim itself is **not included in the portable archive**. If a ConTeXt document
uses the Vim highlighter at runtime, the execution environment (including
`context-agent`) must provide a `vim` executable in `PATH`. Ordinary
ConTeXt documents do not need Vim. See `tests/README.md`.

Copy it over the location already referenced in `context-agent` jobs:

```bash
cp -L result-sandbox-patched \
  ~/RClone/bleau1975/ChatGPT-Sandbox/context/context-lmtx-ready.tar.xz
```

To inspect the package before uploading:

```bash
mkdir -p /tmp/ctx-portable
cd /tmp/ctx-portable
tar -xJf ~/RClone/bleau1975/ChatGPT-Sandbox/context/context-lmtx-ready.tar.xz
cat context-lmtx-ready/manifest.json
./context-lmtx-ready/tex/texmf-linux-64/bin/luametatex --version
printf '\\starttext ConTeXt test \\stoptext\n' > test.tex
./context-lmtx-ready/context-local.sh --once test.tex
```

### Font consistency and limitations

The **engine and all retained TeX/font runtime assets** are identical to the
corresponding files in the NixOS package, excluding only the documented
reference and MkII paths above. Both NixOS and
the portable bundle use the upstream `.lmt` runners; LuaSocket is not enabled. Your original
NixOS wrapper deliberately also finds Nix-managed fonts under
`/run/current-system/sw/share/{X11/fonts,fonts}` and user fonts. These are not
part of the ConTeXt derivation and therefore *cannot automatically* be shipped
with it. The sandbox uses bundled TeX fonts (and optional `OSFONTDIR` supplied
by the caller). To guarantee identical PDF glyphs, use fonts bundled in
`texmf.zip`, or explicitly add and pin further fonts in a future revision.

The archive is `x86_64-linux` only; it will not run on macOS or ARM64.
The target must use a compatible Linux kernel and CPU for the Nix-built engine.
Its execution outside Nix is checked by the build-time smoke tests, but the
actual ChatGPT Hosted runtime should also be smoke-tested after uploading.

The productive `.#context` applies the Math/Glue patch, but it does not
change ConTeXt's unit handling. Both `.#context-2024` and
`.#context-upstream` are unpatched comparison builds.

## Upstream LMTX 2026 runner compatibility

LuaMetaTeX 2.11.10's default build has no LuaSocket. That is correct:
`mtxrun.lmt`/`context.lmt` work without it, whereas the deprecated
`mtxrun.lua` requires `socket.core`. The package now installs the upstream
`.lmt` runners and engine symlinks and verifies `mtx-context.lua` lookup,
format generation and PDF rendering during the **local package build**.

On the portable side, `ld-linux --argv0` preserves the `context`/`mtxrun`
engine entrypoint name; companion `.lmt` files remain beside the binary.
The portable cache readiness marker is written only after successful format
generation, not when the directory first appears.

There is no need to install LuaSocket or copy new Lua modules. The bootstrap
`texmf.zip` remains pinned independently, while `filter` and `vim` now
come from the `filter-src` input at `ca120d8`. No local module patch is
applied. The system/user font search configuration from the original NixOS
launcher is not modified.
