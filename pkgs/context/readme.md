# ConTeXt LMTX – shared NixOS / portable sandbox builds

## Variants, source revisions and checks

The root `flake.lock` pins the ConTeXt source for **all** engine variants.
`.#context` is always the unpatched upstream engine. Experimental variants
are registered by name in the root `flake.nix` as independent patch stacks;
none is installed globally or automatically added to a development shell.
The separate filter-module compatibility fix is shared by all variants; it
is not an engine patch.

| Output | Purpose |
| --- | --- |
| `.#context` | Unpatched engine (same pinned source) |
| `.#context-math-glue-noautobreak` | Our existing experimental math/glue fix |
| `.#context-hans-2026-10-28` | Hans Hagen's supplied `texlinebreak.c` proposal (snapshot 28 October 2026) |
| `.#context-patched` | Compatibility alias for `.#context-math-glue-noautobreak` |
| `.#context-sandbox` | Portable archive built from `.#context` |
| `.#context-sandbox-patched` | Portable archive built from the existing local fix |
| `.#context-docs` | Optional documentation archive from the upstream engine |

`contextVariantPatches` in the root flake maps variant names to **ordered**
engine patch lists. Each variant is built separately from `pkgs.contextLmtx`
using the existing `enginePatches` argument; the lists are never combined by
default. The `contextVariantPackages` mapping exports each entry automatically
as `.#context-<variant-name>` (no additional output declaration needed).
To add another experiment, add its patch file and a new registry entry.
Give new proposals a dated name instead of silently replacing an old one.

The Hans patch was generated from the supplied original `texlinebreak.c` and
Hans' emailed replacement file, without changing his implementation. The patch
applies only to `source/luametatex/source/tex/texlinebreak.c`. Its exact base
must match the pinned `context-src`; a rejected hunk means the upstream version
needs to be checked, **not** that the patch should be applied with more fuzz.
The engine derivation explicitly uses `--fuzz=0` for its patches.
A successful build proves compilation/smoke tests, not math-penalty correctness.

Build any desired variants without switching the system or altering a shell:

```bash
# Newly added patch files must be tracked by git before nix can see them.
git add pkgs/context/patches/luametatex-hans-2026-10-28.patch
nix build .#context -o result-context-unpatched -L
nix build .#context-math-glue-noautobreak -o result-context-patched -L
nix build .#context-hans-2026-10-28 -o result-context-hans -L

# Explicit execution; only the selected binary is run.
./result-context-hans/bin/context --version
```

The reusable `mkContextDevShell` still accepts **one** `contextPackage` and
puts exactly that package's `context` executable on `PATH`. Other variants
are available via explicit result paths, without adding more than one `context`
to any shell. The root `devShells.context` remains the small Python-only
verification shell and is unchanged by this registry.

Each build runs its own smoke, filter, Vim, and cache checks. The comparative
12-case and 76-case Math/Glue/Penalty tests have moved to the independent
`context-testsuite` repository, including their expected results and PDF
analysis. They are **not** part of these builds and are only executed when
explicitly requested. See [`tests/README.md`](tests/README.md) for exact
commands and the division between build, host, and behavioral tests.
A successful package build does not establish typographic correctness.

**Historical sources:** For the precise 2024.11.01 reference, override only
`context-src` (the `texmf.zip` hash stays pinned as usual):

```bash
REV=0d2ec448a05c3cf7e83d79ad62eb485f48464872
nix build .#context-sandbox \
  --override-input context-src "github:contextgarden/context/$REV" \
  -o result-sandbox-2024 -L
```

The derivation discovers the actual `.lua` or `.lmt` runner scripts in the
unpacked source instead of checking for a particular commit hash. Only the
basic smoke test runs for `.lua` sources; the modern filter/Vim checks run
for `.lmt` sources. The historical build reuses the same pinned `texmf.zip` font bundle.
Those fonts have changed little over the years; there is no reason to fetch a
separate historical font archive just for this investigation. The external
filter/Vim modules remain independently pinned. The experimental C patch is
intentionally **not** requested for the historical build.

## One source and one local build

**Use only the root flake** (`NixOS-Config/flake.nix`). The historical
`pkgs/context/flake.nix` and its independent lock file have been removed:
all ConTeXt builds are pinned by the root `flake.lock` only. There is no
`pkgs/context/default.nix`; legacy `nix-build` entrypoints are unsupported.

The root flake has an independent, non-flake `context-src` input pointing to
`contextgarden/context`. Its actual revision and NAR hash are recorded in the
**root `flake.lock`**. Its pin is independent of `nixpkgs` and Home
Manager: updating only `context-src` does not update NixOS. `pkgs/context/luametatex.nix`
consumes that source. The existing TeX-tree installation, filter/vim files and the NixOS font
setup are preserved. The modern launchers use the official `.lmt` entrypoints
(`mtxrun.lmt` and `context.lmt`); historical versions use `.lua`. The pinned `texmf.zip` provides the missing
bootstrap and font files. The pinned `adityam/filter` source provides BOTH
`filter` and `vim`; neither is independently updated with ConTeXt.

The checked-in `patches/filter-lmtx-writable.patch` corrects **only**
`t-filter.mkxl` after copying it into the Nix output; it is a temporary,
version-checked compatibility fix for new temporary files. The MkIV module is
unchanged. Remove this patch after the upstream filter PR has been merged and
our pinned filter revision has been updated, **not before** the tests pass.
No engine patch is applied to the **regular** package; `context-patched`
contains the local LuaMetaTeX C patch. It is a usable, explicitly selected
variant, not merely a short-lived test artifact. Every variant stays pinned
until you deliberately update `context-src`. At update time, run the independent
behavioral suite against both versions to decide whether the patch is still
needed; a patch that no longer applies does not by itself prove the underlying
bug was fixed upstream.

To update only ConTeXt, build and test the candidate **before updating any
consumer project's lock file**. This is a development-shell package; no NixOS
system switch is necessary to use it.
Because the main flake is Git-backed, **stage newly added files first** (Nix
flakes cannot see untracked local files):

```bash
# Newly created, untracked Nix files must be staged before a flake build.
# A source-only update does not require staging any source files.
nix flake update context-src
git diff -- flake.lock
nix build .#context -o result-context --show-trace
./result-context/bin/context --version
nix build .#context-sandbox -o result-sandbox --show-trace
nix develop .#context -c python3 pkgs/context/verify-bundle.py \
  result-context result-sandbox
```

All named variants use exactly the same `context-src` revision from the root
`flake.lock`. Routine builds do **not** need `nix flake update`.
A successful build does not prove correct output for SI prefixes, e.g.
`\unit{micro Volt}`, or for complex layouts; check representative teaching
PDFs before deploying. `texmf.zip` and `adityam/filter` are fixed by hashes
in `luametatex.nix` and are **not** updated together with `context-src`.

After successful package checks and any deliberately invoked
`context-testsuite` regression run, commit the new `flake.lock`. **Do not run
`nixos-rebuild switch` just to install ConTeXt:** it is not installed on the
hosts. Instead, projects such as `unterrichts-texte` pin the `nixos-config`
input in their **own** `flake.lock` and can deliberately update that input
after this change has been committed and pushed. A failed *uncommitted* update
can be reverted with `git restore flake.lock` if it does not contain other
edits. Avoid plain `nix flake update`, which refreshes all inputs.

To enter the small ConTeXt verification environment interactively:

```bash
nix develop .#context
python3 pkgs/context/verify-bundle.py result-context result-sandbox
```

Python is not installed system-wide by this development shell.

The `lib.mkContextDevShell` helper takes an explicit `contextPackage`;
this repository does not select a global ConTeXt default for either host.
A consumer's development shell can choose `context-patched` as its default.

### Host font regression (Carlito, manual)

This host test is **not run automatically** by a Nix build. To ensure that
the wrapper finds Carlito from the running NixOS system's font paths (not
merely the bundled fonts), run it manually on `kitty` or `tracy`:

```bash
nix build .#context-patched -o result-context-patched -L
pkgs/context/tests/check-system-carlito.sh \
  ./result-context-patched/bin/context
```

For the upstream package, build `.#context -o result-context` and pass
`./result-context/bin/context` instead.

The test uses a new temporary cache, loads Carlito Regular and Bold and
checks the exact system font paths in ConTeXt's log. It requires Carlito to
be present system-wide and cannot run inside a pure Nix build sandbox.
For details and a portable debug override, see `tests/README.md`.

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

`nix build .#context-sandbox -o result-sandbox` yields a **regular `.tar.xz`
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
`.#context-sandbox`. The local NixOS package still has the complete upstream
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
git add flake.nix pkgs/context/docs.nix \
  pkgs/context/make-docs-manifest.py pkgs/context/verify-docs.py
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
cp -L result-sandbox \
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

The upstream `.#context` variant deliberately **does not patch ConTeXt's
units or the LuaMetaTeX C engine**. Engine changes remain explicit in the
`enginePatches` list of the `context-patched` variant; they are not silently
applied to the upstream variant.

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

There is no need to install LuaSocket or copy new Lua modules. The pinned
`texmf.zip`, `filter` and `vim` sources remain unchanged; the LMTX-specific
filter compatibility patch is applied to the installed copy only. The system/user font search
configuration from the original NixOS launcher is not modified.
