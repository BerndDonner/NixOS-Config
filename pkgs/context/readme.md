# ConTeXt LMTX – shared NixOS / portable sandbox builds

## Variants, source revisions and checks

The root `flake.lock` pins the ConTeXt source. The main package is deliberately
**unpatched at the LuaMetaTeX engine level**, and remains the version installed
on kitty/tracy through `pkgs.contextLmtx`. The temporary filter-module fix is
part of both modern variants; it is not an engine patch.

| Output | Purpose |
| --- | --- |
| `.#context` | Normal upstream LuaMetaTeX engine, local package |
| `.#context-patched` | Identical source with experimental math/glue C patch |
| `.#context-sandbox` | Portable archive made from `.#context` |
| `.#context-sandbox-patched` | Portable archive made from `.#context-patched` |
| `.#context-docs` | Optional documentation archive from the regular package |
| `.#checks.x86_64-linux.context-math-nobreak` | Reproducible comparison of both local builds |

The package derivation (`luametatex.nix`) accepts an explicit `enginePatches`
list (empty by default). The flake selects the patch for `context-patched`;
no commit-hash heuristic enables experimental fixes. Changing `context-src`
changes the source for **both** modern variants; an incompatible patch causes
the patched build to fail explicitly rather than silently doing nothing.

To build and compare without changing any system package:

```bash
nix build .#context -o result-context -L
nix build .#context-patched -o result-context-patched -L
nix build .#checks.x86_64-linux.context-math-nobreak \
  -o result-context-math-nobreak -L
```

The check preserves its `before/` and `after/` PDFs, logs and text output in
the Nix result path. To rerun manually, see `tests/math-nobreak/README.md`.
Passing the check does not guarantee that all typography is unchanged.
Inspect representative teaching documents before selecting any experimental
variant for actual use.

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
No engine patch is applied to the **regular** package; the separate
`context-patched` output deliberately applies one experimental LuaMetaTeX
C patch for testing.

To update only ConTeXt, then test it **before switching your system**.
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

Both builds use exactly the same `context-src` revision from the root
`flake.lock`. Routine builds do **not** need `nix flake update`.
A successful build does not prove correct output for SI prefixes, e.g.
`\unit{micro Volt}`, or for complex layouts; check representative teaching
PDFs before deploying. `texmf.zip` and `adityam/filter` are fixed by hashes
in `luametatex.nix` and are **not** updated together with `context-src`.

After a successful comparison, commit the new `flake.lock` and rebuild the
intended host using `sudo nixos-rebuild switch --flake .#kitty` or `.#tracy`.
The build itself does not install the new version system-wide. For a failed
uncommitted update, `git restore flake.lock` restores the prior pin, provided
no unrelated lock-file changes should be kept. Avoid plain `nix flake update`,
which refreshes all inputs. Consumers such as `unterrichts-texte` may also
have their own lock of the `nixos-config` input; a remote input must be updated
there separately after committing/pushing the new revision here.

To enter the small ConTeXt verification environment interactively:

```bash
nix develop .#context
python3 pkgs/context/verify-bundle.py result-context result-sandbox
```

Python is not installed system-wide by this development shell.

Home Manager on `kitty` and `tracy` installs the same `pkgs.contextLmtx`.
Use your normal NixOS rebuild workflow only after the builds pass.

### Host font regression (Carlito)

After `nix build .#context` and before switching your NixOS system, verify
that the **installed wrapper** still discovers Carlito from the system font
paths (not only the fonts bundled in the TeX tree):

```bash
pkgs/context/tests/check-system-carlito.sh ./result-context/bin/context
```

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

The regular package deliberately **does not patch ConTeXt's units or the
LuaMetaTeX C engine**. Further proposed engine fixes should be added to an
explicit `enginePatches` list on a separate variant, not silently added to
the default package.

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
