# ConTeXt LMTX – shared NixOS / ChatGPT Sandbox build

## One source and one local build

**Use the root flake** (`NixOS-Config/flake.nix`), not the historical standalone
`pkgs/context/flake.nix`. The latter is kept for backwards compatibility but
uses its own older lock file and is not the supported update path.

The root flake has an independent, non-flake `context-src` input pointing to
`contextgarden/context`. Its actual revision and NAR hash are recorded in the
**root `flake.lock`**. `pkgs/context/luametatex.nix` consumes that source. The existing TeX-tree installation, filter/vim files and the NixOS font
setup are preserved. Only the upstream launcher integration is updated to the
2026 `.lmt` entrypoints (`mtxrun.lmt` and `context.lmt`). The pinned `texmf.zip` provides the missing bootstrap and
font files. The pinned `adityam/filter` source provides BOTH `filter` and `vim`.
No independent filter update occurs when ConTeXt is updated.

To update only ConTeXt, then test it **before switching your system**.
Because the main flake is Git-backed, **stage newly added files first** (Nix
flakes cannot see untracked local files):

```bash
git add flake.nix modules/home-manager/packages.nix pkgs/context
nix flake update context-src
nix build .#context -o result-context --show-trace
./result-context/bin/context --version
nix build .#context-sandbox -o result-sandbox --show-trace
python3 pkgs/context/verify-bundle.py result-context result-sandbox
```

**For the first build after applying the patch:** the new input is not present
in the old lock file. `nix flake update context-src` must be run once on a
networked machine. Commit the regenerated `flake.lock` together with this
change. Future builds use precisely that locked revision without updating
anything on their own.

Home Manager on `kitty` and `tracy` installs the same `pkgs.contextLmtx`.
Use your normal NixOS rebuild workflow only after the builds pass.

## Sandbox archive

`nix build .#context-sandbox -o result-sandbox` yields a **regular `.tar.xz`
file**, with the same root layout as the previous
`context-lmtx-ready.tar.xz`. The archive includes:

- exactly the installed engine and ConTeXt tree from `packages.context`;
- the pinned `texmf.zip` files, fonts, `filter` and `vim` modules;
- the ELF loader and the dynamically resolved shared libraries (without Nix);
- `context-local.sh` and `manifest.json` with source revision, engine SHA256
  and a deterministic SHA256 over the complete TeX tree.

The sandbox builder does **not** fetch, compile or install a second ConTeXt.
It fails unless the ELF wrapper starts and two separate ConTeXt documents
compile: a font/unit/MetaPost smoke test, and a `filter`+`vim` loading test.

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

The **engine and bundled TeX/font tree** are built identically. Both NixOS and
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

The current implementation deliberately **does not patch ConTeXt's units**.
Those changes can later be added to the shared `luametatex.nix` via a small,
version-checked `patches` list and will then affect both outputs.

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
`texmf.zip`, `filter` and `vim` remain unchanged. The system/user font search
configuration from the original NixOS launcher is not modified.
