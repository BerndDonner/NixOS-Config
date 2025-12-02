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

    # Small helper to create wrappers for mtxrun/context
    makeWrapper() {
      local name="$1"
      local luaScript="$2"

      cat > "$out/bin/$name" <<'EOF'
#!${runtimeShell}
# Per-user cache directory; ConTeXt will append "luametatex-cache/context/<hash>".
export TEXMFCACHE="''${XDG_CACHE_HOME:-$HOME/.cache}"

# System + user font search paths (only if not set by user)
if [ -z "''${OSFONTDIR:-}" ]; then
  OSFONTDIR="/run/current-system/sw/share/X11/fonts"
  OSFONTDIR="$OSFONTDIR:/run/current-system/sw/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.local/share/fonts"
  OSFONTDIR="$OSFONTDIR:$HOME/.fonts"
  export OSFONTDIR
fi
EOF

      cat >> "$out/bin/$name" <<EOF
# Ensure user cache is initialized (idempotent)
"$out/bin/context-init-cache"

# Call LuaMetaTeX with the proper frontend
exec "$out/tex/texmf-linux-64/bin/luametatex" --luaonly \
  "$out/tex/texmf-linux-64/bin/$luaScript" "\$@"
EOF

      chmod +x "$out/bin/$name"
    }

    # Raw engine wrapper: do not force TEXMFCACHE/OSFONTDIR here
    cat > "$out/bin/luametatex" <<EOF
#!${runtimeShell}
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

    # Important: do NOT generate caches in the Nix store.
    # Font and format caches will be created per user at runtime
    # (mtxrun --generate, mtxrun --script fonts --reload, context --make).

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
