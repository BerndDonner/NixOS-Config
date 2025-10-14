{ lib, python3, fetchFromGitHub, buildPythonPackage }:

buildPythonPackage rec {
  pname = "pygame";
  version = "2.6.1-avx2";

  src = fetchFromGitHub {
    owner = "pygame";
    repo = "pygame";
    rev = "release-${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # fill with real hash
  };

  prePatch = ''
    sed -i "s/distutils.ccompiler.spawn/distutils.spawn.spawn/" setup.py
  '';

  buildPhase = ''
    export PYGAME_DETECT_AVX2=1
    python setup.py -config -auto
    python setup.py build
  '';

  meta = with lib; {
    description = "Pygame built with AVX2 enabled";
    license = licenses.lgpl2;
  };
}

