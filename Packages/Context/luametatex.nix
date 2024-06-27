# based on the work of Marco Feltmann: https://github.com/marcofeltmann/luametatex.nix/blob/master/context.nix

{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchzip,
  runtimeShell,
  cmake,
  coreutils,
  gcc,
  gnumake,
  ninja,
} :

stdenv.mkDerivation {
  pname = "LuaMetaTeX";
  version = "2.11.04"; #TODO can we automatically set the version from github?

  meta = with lib; {
    description = "The LuaMetaTeX project, related to ConTeXt development, closely integrates TeX and MetaPost with Lua.";
    homepage    = "https://www.pragma-ade.nl/download-1.htm";
    license     = licenses.gpl2;
    platforms   = platforms.linux;
    maintainers = [ ]; #TODO
  };

  src = fetchFromGitHub {
    owner = "contextgarden";
    repo = "context";
    rev = "1b2969ec0070260690fc2d1e27ee37435ed49ce0";
    hash = "sha256-cGv/0RfPEAS3Bk1tH+JOxs1vsNXyv2n2JsDexjZ+nBY=";
  };


  # Documentation: http://www.pragma-ade.nl/install.htm
  texmf = fetchzip {
    url = "http://lmtx.pragma-ade.nl/install-lmtx/texmf.zip";
    sha256 = "sha256-J7iYpmjTMdv8rngzJ58vtC+K2VmP3pfgQDLLxFxYSbA=";
  };

  nativeBuildInputs = [
    cmake
    coreutils
    gcc
    gnumake
    ninja
  ];

  configurePhase = ''
    cmake "$src/source/luametatex/"
  '';

  buildPhase = ''
    make all
  '';

  # The let .. in .. construct seems perfect for this function definition,
  # since I do not want the function definition to be visible to the outside
  # the function createWrapper is only an internal helper to prevent repetitive
  # code.
  #
  # all the wrapper does is calling context, mtxrun and luametatex with the
  # absolute path. Changing the filenames of theese binaries would break the code
  # by the way. The impementation of the only real binary luametatex does find
  # the fonts and other neccessary data when called via absolute path.

  postUnpack =
    let

      createWrapper=filename : ''
        echo '#!${runtimeShell}'                                  >  "$out/bin/${filename}"
        echo exec "$out/tex/texmf-linux-64/bin/${filename}" "\$@" >> "$out/bin/${filename}"
        chmod a+x "$out/bin/${filename}"
      '';

    in

      ''
      echo "prepare file structure"

      mkdir -p "$out/bin"
      mkdir -p "$out/tex/texmf-context"
      mkdir -p "$out/tex/texmf-linux-64/bin"

      echo "***** DEBUG *****"
      pwd
      echo $src
      echo $out
      echo $texmf
      echo $context
      echo ${runtimeShell}
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

    '';

# The following buildsteps where missing:
# 1.) copy texmf (source http://www.pragma-ade.nl/install.htm -> texmf.zip)
#     to the same directory that also contains texmf-cache
# 2.) wipe the texmf-cache directory (not needed for clean build)
# 3.) mtxrun --generate
# 4.) mtxrun --script fonts --reload
# 5.) context --make

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
}

