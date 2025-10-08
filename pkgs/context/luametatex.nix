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
  version = "2.11.06";

  src = fetchFromGitHub {
    owner = "contextgarden";
    repo  = "context";
    rev   = "0d2ec448a05c3cf7e83d79ad62eb485f48464872";
    hash  = "sha256-T+v0mX1aY+G8hoAgM4OvYvvPUq+uW/p2I0SUzN9J1aQ=";
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

    echo "🧩 Installing LuaMetaTeX / ConTeXt tree"
    mkdir -p "$out/bin" "$out/tex/texmf-linux-64/bin" "$out/tex/texmf-context"

    # Copy compiled binary and Lua helpers
    cp build/luametatex "$out/tex/texmf-linux-64/bin/"
    cp "$src/scripts/context/lua/"{mtxrun.lua,context.lua} "$out/tex/texmf-linux-64/bin/"

    # ----------------------------------------------------------------------------
    # Create wrappers (luametatex, mtxrun, context)
    # ----------------------------------------------------------------------------
    echo '#!${runtimeShell}' > "$out/bin/luametatex"
    echo "exec \"$out/tex/texmf-linux-64/bin/luametatex\" \"\$@\"" >> "$out/bin/luametatex"
    chmod +x "$out/bin/luametatex"

    echo '#!${runtimeShell}' > "$out/bin/mtxrun"
    echo "exec \"$out/tex/texmf-linux-64/bin/luametatex\" --luaonly \"$out/tex/texmf-linux-64/bin/mtxrun.lua\" \"\$@\"" >> "$out/bin/mtxrun"
    chmod +x "$out/bin/mtxrun"

    echo '#!${runtimeShell}' > "$out/bin/context"
    echo "exec \"$out/tex/texmf-linux-64/bin/luametatex\" --luaonly \"$out/tex/texmf-linux-64/bin/context.lua\" \"\$@\"" >> "$out/bin/context"
    chmod +x "$out/bin/context"

    # ----------------------------------------------------------------------------
    # Copy TeX tree
    # ----------------------------------------------------------------------------
    echo "📦 Copying TeX trees"
    cp -r "$texmf/texmf" "$out/tex/"
    for d in colors context doc fonts metapost scripts tex web2c; do
      cp -r "$src/$d" "$out/tex/texmf-context/"
    done

    # Ensure write permission before adding extra modules
    chmod -R u+w "$out"

    # ----------------------------------------------------------------------------
    # Add third-party modules (filter + vim)
    # ----------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------
    # Generate texmf cache
    # ----------------------------------------------------------------------------
    echo "⚙️  Generating texmf-cache"
    "$out/bin/mtxrun"  --generate
    "$out/bin/mtxrun"  --script fonts --reload
    "$out/bin/context" --make

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

