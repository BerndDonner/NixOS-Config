{
  description = "Flake for LuaMetaTeX, related to ConTeXt development.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11"; # Add the appropriate nixpkgs version
    moduleFilter.url = "github:adityam/filter";
    luametatex.url = "github:contextgarden/context";
  };

  outputs = { self, nixpkgs, moduleFilter, luametatex }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
      lib = pkgs.lib;
    in
    {
      packages.x86_64-linux.LuaMetaTeX = pkgs.stdenv.mkDerivation rec {
        pname = "LuaMetaTeX";
        version = "2.11.06";

        meta = with lib; {
          description = "The LuaMetaTeX project, related to ConTeXt development, closely integrates TeX and MetaPost with Lua.";
          homepage    = "https://www.pragma-ade.nl/download-1.htm";
          license     = licenses.gpl2;
          platforms   = platforms.linux;
        };

        # Use inputs for dependencies
        src = luametatex;

        moduleFilter = moduleFilter;

        texmf = pkgs.fetchzip {
          url = "http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip";
          sha256 = "sha256-do9iXJz20OigCiQAb5AREAqYjBYdHRxXVZUTtw23TGI=";
        };

        nativeBuildInputs = [
          pkgs.cmake
          pkgs.coreutils
          pkgs.gcc
          pkgs.gnumake
          pkgs.ninja
        ];

        configurePhase = ''
          cmake "$src/source/luametatex/"
        '';

        buildPhase = ''
          make all
        '';

        postUnpack =
          let
            createWrapper = filename: ''
              echo '#!${pkgs.runtimeShell}'                                  >  "$out/bin/${filename}"
              echo exec "$out/tex/texmf-linux-64/bin/${filename}" "\$@" >> "$out/bin/${filename}"
              chmod a+x "$out/bin/${filename}"
            '';
          in ''
            echo "prepare file structure"

            mkdir -p "$out/bin"
            mkdir -p "$out/tex/texmf-context"
            mkdir -p "$out/tex/texmf-linux-64/bin"

            echo "***** DEBUG *****"
            pwd
            echo $src
            echo $out
            echo $texmf
            echo $moduleFilter
            echo ${pkgs.runtimeShell}
            echo "****** END ******"

            ${createWrapper "context"}
            ${createWrapper "mtxrun"}
            ${createWrapper "luametatex"}

            cp -r "$texmf/texmf"  "$out/tex/"
            cp -r "$src/colors"   "$out/tex/texmf-context/"
            cp -r "$src/context"  "$out/tex/texmf-context/"
            cp -r "$src/doc"      "$out/tex/texmf-context/"
            cp -r "$src/fonts"    "$out/tex/texmf-context/"
            cp -r "$src/metapost" "$out/tex/texmf-context/"
            cp -r "$src/scripts"  "$out/tex/texmf-context/"
            cp -r "$src/tex"      "$out/tex/texmf-context/"
            cp -r "$src/web2c"    "$out/tex/texmf-context/"

            chmod -R u+w $out/

            mkdir -p $out/tex/texmf-context/tex/context/third/filter/
            mkdir -p $out/tex/texmf-context/doc/context/third/filter/

            cp $moduleFilter/README.md $out/tex/texmf-context/doc/context/third/filter/
            cp $moduleFilter/t-filter* $out/tex/texmf-context/tex/context/third/filter/
            cp $moduleFilter/t-module* $out/tex/texmf-context/tex/context/third/filter/

            mkdir -p $out/tex/texmf-context/tex/context/third/vim/
            mkdir -p $out/tex/texmf-context/doc/context/third/vim/

            cp $moduleFilter/vim-README.md $out/tex/texmf-context/doc/context/third/vim/
            cp $moduleFilter/t-syntax-* $out/tex/texmf-context/tex/context/third/vim/
            cp $moduleFilter/2context.vim $out/tex/texmf-context/tex/context/third/vim/
            cp $moduleFilter/t-vim.tex $out/tex/texmf-context/tex/context/third/vim/
            cp $moduleFilter/vimtyping-default.css $out/tex/texmf-context/tex/context/third/vim/
          '';

        installPhase = ''
          echo "prepare binaries"

          cp luametatex                      "$out/tex/texmf-linux-64/bin/"
          cp scripts/context/lua/mtxrun.lua  "$out/tex/texmf-linux-64/bin/mtxrun.lua"
          cp scripts/context/lua/context.lua "$out/tex/texmf-linux-64/bin/context.lua"
          ln -s "$out/tex/texmf-linux-64/bin/luametatex" "$out/tex/texmf-linux-64/bin/mtxrun"
          ln -s "$out/tex/texmf-linux-64/bin/luametatex" "$out/tex/texmf-linux-64/bin/context"

          echo "generate texmf-cache"

          "$out/tex/texmf-linux-64/bin/mtxrun"  --generate
          "$out/tex/texmf-linux-64/bin/mtxrun"  --script fonts --reload
          "$out/tex/texmf-linux-64/bin/context" --make
        '';
      };
    };
}

