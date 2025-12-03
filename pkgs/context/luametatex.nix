{ lib
, stdenv
, fetchFromGitHub
, fetchzip
, cmake
, coreutils
, gnumake
, ninja
, runtimeShell
}:

stdenv.mkDerivation rec {
  pname = "luametatex";
  version = "2.11.07";

  src = fetchFromGitHub {
    owner = "contextgarden";
    repo  = "context";
    rev   = "41a8e614f633b55052f2087ee9400130eb432b54";
    hash  = "sha256-8yuhTSsnb5ud62CpKgHa+qNZWSJZi9tR8wvSGu4oJ08=";
  };

  moduleFilter = fetchFromGitHub {
    owner = "adityam";
    repo  = "filter";
    rev   = "6e4cc8206d2f70e1228f2ca52e0738979873a885";
    hash  = "sha256-/9uvk3+RC0PGyWNfaZP0mss8UXMs+GBlXhGmHr7dQp4=";
  };

  texmf = fetchzip {
    url    = "http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip";
    sha256 = "sha256-do9iXJz20OigCiQAb5AREAqYjBYdHRxXVZUTtw23TGI=";
  };

  nativeBuildInputs = [ cmake gnumake ninja coreutils ];

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

    # Engine + Lua frontends
    cp build/luametatex "$out/tex/texmf-linux-64/bin/"
    cp "$src/scripts/context/lua/"{mtxrun.lua,context.lua} \
       "$out/tex/texmf-linux-64/bin/"

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
ENGINE="$out/tex/texmf-linux-64/bin/luametatex"
MTXRUN_LUA="$out/tex/texmf-linux-64/bin/mtxrun.lua"
CONTEXT_LUA="$out/tex/texmf-linux-64/bin/context.lua"

echo "Initializing ConTeXt cache in \$CACHE_ROOT/luametatex-cache ..." >&2

mkdir -p "\$CACHE_ROOT"
"\$ENGINE" --luaonly "\$MTXRUN_LUA" --generate
"\$ENGINE" --luaonly "\$MTXRUN_LUA" --script fonts --reload
"\$ENGINE" --luaonly "\$CONTEXT_LUA" --make
EOF
    chmod +x "$out/bin/context-init-cache"

    # ----------------------------------------------------------------------
    # Small helper to create wrappers for mtxrun/context
    # ----------------------------------------------------------------------
    makeWrapper() {
      local name="$1"
      local luaScript="$2"

    initEnvironment "$name"

    cat >> "$out/bin/$name" <<EOF
CACHE_CONTEXT_DIR="\$CACHE_ROOT/luametatex-cache/context"

# One-time initialization of cache + formats + font DB
if [ ! -d "\$CACHE_CONTEXT_DIR" ]; then
  "$out/bin/context-init-cache"
fi

exec "$out/tex/texmf-linux-64/bin/luametatex" --luaonly \
  "$out/tex/texmf-linux-64/bin/$luaScript" "\$@"
EOF

      chmod +x "$out/bin/$name"
    }

    # Raw engine wrapper: do not force TEXMFCACHE/OSFONTDIR here
    cat > "$out/bin/luametatex" <<EOF
#!${runtimeShell}
set -euo pipefail

exec "$out/tex/texmf-linux-64/bin/luametatex" "\$@"
EOF
    chmod +x "$out/bin/luametatex"

    # mtxrun + context with cache/fonts setup
    makeWrapper mtxrun  mtxrun.lua
    makeWrapper context context.lua

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

  meta = with lib; {
    description = "LuaMetaTeX engine (ConTeXt LMTX) – integrates TeX and MetaPost with Lua";
    homepage    = "https://wiki.contextgarden.net";
    license     = licenses.gpl2;
    platforms   = platforms.unix;
    maintainers = [ ];
  };

  passthru.tests.smoke = ''
    $out/bin/luametatex --version
  '';
}
