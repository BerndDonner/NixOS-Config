{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, cmake
, coreutils
, gnumake
, ninja
, runtimeShell
, vim
, patch
, util-linux
, contextSource
, contextRevision
}:

stdenv.mkDerivation rec {
  pname = "luametatex";
  # The source is pinned exclusively by the root flake.lock.
  version = "unstable-${builtins.substring 0 12 contextRevision}";
  src = contextSource;

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

  # Real filter/Vim tests run during the build; these tools are not
  # runtime dependencies of the installed NixOS ConTeXt package.
  nativeBuildInputs = [ cmake gnumake ninja coreutils vim patch ];

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
FLOCK="${util-linux}/bin/flock"
CACHE_MARKER="\$CACHE_ROOT/.context-ready-$(basename "$out")"
LOCK_FILE="\$CACHE_ROOT/.context-init-$(basename "$out").lock"

# Explicit invocation without arguments still forces a rebuild.
# The context wrapper uses --if-needed and rechecks under the lock.
mode=--force
if [ "\$#" -gt 0 ]; then
  if [ "\$#" -ne 1 ]; then
    echo 'Usage: context-init-cache [--force|--if-needed]' >&2
    exit 2
  fi
  mode="\$1"
fi
case "\$mode" in
  --force|--if-needed) ;;
  *) echo 'Usage: context-init-cache [--force|--if-needed]' >&2; exit 2 ;;
esac

mkdir -p "\$CACHE_ROOT"
# An open file descriptor holds a kernel-managed lock. It is released on
# exit, including when initialization fails or the process is killed.
exec 9>"\$LOCK_FILE"
"\$FLOCK" -x 9

if [ "\$mode" = --if-needed ] && [ -f "\$CACHE_MARKER" ]; then
  exit 0
fi

# Invalidate even a formerly valid marker before an explicit rebuild.
rm -f "\$CACHE_MARKER"
echo "Initializing ConTeXt cache in \$CACHE_ROOT/luametatex-cache ..." >&2
"\$MTXRUN" --generate
"\$MTXRUN" --script fonts --reload
"\$CONTEXT" --make

# Publish only a completely generated cache. A crash while writing the
# temporary file cannot leave a successful-looking readiness marker.
marker_tmp="\$CACHE_MARKER.tmp.\$\$"
trap 'rm -f "\$marker_tmp"' EXIT
printf '%s\\n' '$(basename "$out")' > "\$marker_tmp"
mv -f "\$marker_tmp" "\$CACHE_MARKER"
trap - EXIT
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
  "$out/bin/context-init-cache" --if-needed
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

    # The copied Git tree may contain read-only directories (Nix store).
    # Only these parents must be writable to add third-party modules;
    # do not recursively chmod the entire TeX tree.
    chmod u+w \
      "$out/tex/texmf-context/tex/context" \
      "$out/tex/texmf-context/doc/context"

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
    # Temporary compatibility fix for adityam/filter (LMTX only).
    # Keep MkIV unchanged; upstream ConTeXt bugs remain upstream.
    # Fail rather than silently ignore upstream changes to this module.
    filter_dir="$out/tex/texmf-context/tex/context/third/filter"
    chmod u+w "$filter_dir/t-filter.mkxl"
    patch --batch --fuzz=0 -d "$filter_dir" -p0 < ${./patches/filter-lmtx-writable.patch}

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
    for test_name in smoke filter vim; do
      # New temporary files are essential to reproduce the LMTX bug.
      test_dir="$TMPDIR/context-smoke-doc/$test_name"
      mkdir -p "$test_dir"
      cp "${./tests}/$test_name.tex" "$test_dir/$test_name.tex"
      (
        cd "$test_dir"
        "$out/bin/context" --once "$test_name.tex" > "$TMPDIR/ctx-$test_name.log" 2>&1 || {
          cat "$TMPDIR/ctx-$test_name.log" >&2; exit 1;
        }
        test -s "$test_name.pdf" || {
          echo "Missing or empty PDF for $test_name" >&2; exit 1;
        }
        if [ "$test_name" = filter ]; then
          grep -Fq 'The external filter created its temporary files.' \
            filter-temp-copy.tex || {
              echo 'The external copy filter did not produce its output' >&2
              exit 1
            }
        fi
        if [ "$test_name" = vim ]; then
          # A PDF can still be created if highlighting silently fails.
          # Inspect Vim's intermediate TeX instead of only checking the PDF.
          if ! grep -Fq '\SYN[' vim-temp-PYTHON-0.vimout; then
            echo 'Vim returned no ConTeXt highlighting tokens' >&2
            ls -la >&2
            exit 1
          fi
        fi
      )
    done
    # Exercise two simultaneous first starts and forced reinitialization.
    bash ${./tests/check-native-cache-lock.sh} "$out/bin/context"
  '';

  meta = with lib; {
    description = "LuaMetaTeX engine (ConTeXt LMTX) – integrates TeX and MetaPost with Lua";
    homepage    = "https://wiki.contextgarden.net";
    license     = licenses.gpl2;
    platforms   = [ "x86_64-linux" ];
    maintainers = [ ];
  };

  passthru = {
    # Evaluated metadata; used by the independent sandbox archive derivation.
    inherit contextRevision;
    tests.smoke = ''
      $out/bin/luametatex --version
    '';
  };
}
