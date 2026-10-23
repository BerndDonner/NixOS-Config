{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, cmake
, coreutils
, gnumake
, ninja
, runtimeShell
, contextSource ? null
, contextRevision ? null
}:

stdenv.mkDerivation rec {
  pname = "luametatex";
  # When called from the main flake, the locked context-src input is used.
  # Keep the old fixed-output source as a backwards-compatible fallback for
  # users of the standalone package definition.
  version = if contextSource == null then "2.11.07"
            else "unstable-${builtins.substring 0 12 (if contextRevision == null then "unknown" else contextRevision)}";

  src = if contextSource != null then contextSource else fetchFromGitHub {
    owner = "contextgarden";
    repo  = "context";
    rev   = "41a8e614f633b55052f2087ee9400130eb432b54";
    hash  = "sha256-8yuhTSsnb5ud62CpKgHa+qNZWSJZi9tR8wvSGu4oJ08=";
  };

  # Retain the proven filter/vim release; it is used by teaching documents.
  moduleFilter = fetchFromGitHub {
    owner = "adityam";
    repo  = "filter";
    rev   = "6e4cc8206d2f70e1228f2ca52e0738979873a885";
    hash  = "sha256-/9uvk3+RC0PGyWNfaZP0mss8UXMs+GBlXhGmHr7dQp4=";
  };

  # ConTeXt's Git repository omits this bootstrap/font TeX tree.
  # It is intentionally retained with the original fixed-output hash.
  texmf = fetchzip {
    url    = "http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip";
    sha256 = "sha256-S3kCPJqB+0+CD7S7ai6yalOQihzhHy6XS1krFdWhdVc=";
  };

  nativeBuildInputs = [ cmake gnumake ninja coreutils ];

  # Use the upstream default LuaMetaTeX build (without LuaSocket).
  # ConTeXt 2026 launches through mtxrun.lmt/context.lmt, not mtxrun.lua.
  configurePhase = ''
    cmake -B build -S "$src/source/luametatex" -DCMAKE_BUILD_TYPE=Release
  '';

  buildPhase = ''
    cmake --build build
  '';

  installPhase = ''
    runHook preInstall

    echo "Installing LuaMetaTeX / ConTeXt tree"
    mkdir -p "$out/bin" "$out/tex/texmf-linux-64/bin" "$out/tex/texmf-context"

    # Official ConTeXt LMTX 2026 entrypoints: all three executable names
    # resolve to the same LuaMetaTeX engine, with a companion .lmt script.
    # The deprecated .lua runner needs LuaSocket and must not be invoked.
    cp build/luametatex "$out/tex/texmf-linux-64/bin/"
    cp "$src/scripts/context/lua/"{mtxrun.lmt,context.lmt} \
       "$out/tex/texmf-linux-64/bin/"
    ln -s luametatex "$out/tex/texmf-linux-64/bin/mtxrun"
    ln -s luametatex "$out/tex/texmf-linux-64/bin/context"

    # ----------------------------------------------------------------------
    # init environment helper
    # ----------------------------------------------------------------------

     initEnvironment() {
      local name="$1"

      cat > "$out/bin/$name" <<'EOF'
#!${runtimeShell}
set -euo pipefail

# Per-user cache directory; ConTeXt will append "luametatex-cache/context/<hash>".
if [ -z "''${TEXMFCACHE:-}" ]; then
  TEXMFCACHE="''${XDG_CACHE_HOME:-$HOME/.cache}"
  export TEXMFCACHE
fi

# System + user font search paths (only if not set by user)
if [ -z "''${OSFONTDIR:-}" ]; then
  OSFONTDIR="/run/current-system/sw/share/X11/fonts"
  OSFONTDIR="$OSFONTDIR:/run/current-system/sw/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.local/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.fonts"
  export OSFONTDIR
fi

CACHE_ROOT="''${TEXMFCACHE%/}"
EOF
    }

    # ----------------------------------------------------------------------
    # context-init-cache: one-shot cache + font DB + formats initializer
    # ----------------------------------------------------------------------

    initEnvironment context-init-cache

    cat >> "$out/bin/context-init-cache" <<EOF
MTXRUN="$out/tex/texmf-linux-64/bin/mtxrun"
CONTEXT="$out/tex/texmf-linux-64/bin/context"

echo "Initializing ConTeXt cache in \$CACHE_ROOT/luametatex-cache ..." >&2

mkdir -p "\$CACHE_ROOT"
"\$MTXRUN" --generate
"\$MTXRUN" --script fonts --reload
"\$CONTEXT" --make
# The marker is written only after generate, font reload and format build.
touch "\$CACHE_ROOT/.context-ready-$(basename "$out")"
EOF

    # ----------------------------------------------------------------------
    # luametatex wrapper
    # ----------------------------------------------------------------------
    
    cat > "$out/bin/luametatex" <<EOF
#!${runtimeShell}
set -eu

exec "$out/tex/texmf-linux-64/bin/luametatex" "\$@"
EOF

    # ----------------------------------------------------------------------
    # mtxrun wrapper
    # ----------------------------------------------------------------------
    
    initEnvironment mtxrun

    cat >> "$out/bin/mtxrun" <<EOF
exec "$out/tex/texmf-linux-64/bin/mtxrun" "\$@"
EOF

    # ----------------------------------------------------------------------
    # context wrappers
    # ----------------------------------------------------------------------
    
    initEnvironment context

    cat >> "$out/bin/context" <<EOF
CACHE_MARKER="\$CACHE_ROOT/.context-ready-$(basename "$out")"

# A directory can exist after a failed partial initialization. The marker is
# written only by context-init-cache once all initialization steps succeed.
if [ ! -f "\$CACHE_MARKER" ]; then
  "$out/bin/context-init-cache"
fi

exec "$out/tex/texmf-linux-64/bin/context" "\$@"
EOF

    chmod +x "$out/bin/context-init-cache"
    chmod +x "$out/bin/luametatex"
    chmod +x "$out/bin/mtxrun"
    chmod +x "$out/bin/context"

    # Copy TeX trees
    echo "Copying TeX trees"
    cp -r "$texmf/texmf" "$out/tex/"
    for d in colors context doc fonts metapost scripts tex web2c; do
      cp -r "$src/$d" "$out/tex/texmf-context/"
    done

    # Allow modifications while adding third-party modules
    chmod -R u+w "$out"

    # Third-party modules (filter + vim)
    mkdir -p \
      "$out/tex/texmf-context/tex/context/third/filter" \
      "$out/tex/texmf-context/doc/context/third/filter" \
      "$out/tex/texmf-context/tex/context/third/vim" \
      "$out/tex/texmf-context/doc/context/third/vim"

    cp "$moduleFilter"/README.md \
       "$out/tex/texmf-context/doc/context/third/filter/"
    cp "$moduleFilter"/t-{filter*,module*} \
       "$out/tex/texmf-context/tex/context/third/filter/"
    cp "$moduleFilter"/vim-README.md \
       "$out/tex/texmf-context/doc/context/third/vim/"
    cp "$moduleFilter"/{t-syntax-*,2context.vim,t-vim.tex,vimtyping-default.css} \
       "$out/tex/texmf-context/tex/context/third/vim/"

    # No cache generation in the Nix store!
    # Per-user cache and fonts DB are initialized on first use.

    runHook postInstall
  '';

  # Regression test: catch a missing .lmt launcher, an unresolvable
  # mtx-context.lua or an unusable TeX tree already in the local package.
  # Keep all caches, including format files, outside the read-only Nix store.
  postInstall = ''
    export HOME="$TMPDIR/context-smoke-home"
    export TEXMFCACHE="$TMPDIR/context-smoke-cache"
    mkdir -p "$HOME" "$TMPDIR/context-smoke-doc"
    "$out/bin/mtxrun" --generate > "$TMPDIR/ctx-generate.log" 2>&1 || {
      cat "$TMPDIR/ctx-generate.log" >&2; exit 1;
    }
    located=$("$out/bin/mtxrun" --locate --first mtx-context.lua) || {
      echo "ConTeXt resolver could not locate mtx-context.lua" >&2; exit 1;
    }
    test -f "$located" || {
      echo "ConTeXt resolver returned a missing script: $located" >&2; exit 1;
    }
    "$out/bin/context" --make > "$TMPDIR/ctx-make.log" 2>&1 || {
      cat "$TMPDIR/ctx-make.log" >&2; exit 1;
    }
    cp ${./tests/smoke.tex} "$TMPDIR/context-smoke-doc/smoke.tex"
    (
      cd "$TMPDIR/context-smoke-doc"
      "$out/bin/context" --once smoke.tex > "$TMPDIR/ctx-smoke.log" 2>&1 || {
        cat "$TMPDIR/ctx-smoke.log" >&2; exit 1;
      }
      test -s smoke.pdf
    )
  '';

  meta = with lib; {
    description = "LuaMetaTeX engine (ConTeXt LMTX) – integrates TeX and MetaPost with Lua";
    homepage    = "https://wiki.contextgarden.net";
    license     = licenses.gpl2;
    platforms   = platforms.unix;
    maintainers = [ ];
  };

  passthru = {
    # Evaluated metadata; used by the independent sandbox archive derivation.
    contextRevision = if contextRevision == null then "legacy" else contextRevision;
    tests.smoke = ''
      $out/bin/luametatex --version
    '';
  };
}
