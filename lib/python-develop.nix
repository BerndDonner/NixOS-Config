{ pkgs
, symbol ? "🐍"
, pythonVersion ? pkgs.python311
, extraPackages ? [ ]
, message ? "🐍 Python development environment ready"
}:

let
  promptHook = import ./promptHook.nix { inherit symbol; };
in
pkgs.mkShell {
  name = "python-env";

  # core packages for every Python shell
  packages = with pkgs; [
    pythonVersion
    pythonVersion.pkgs.pip
    pythonVersion.pkgs.setuptools
    pythonVersion.pkgs.wheel
    pythonVersion.pkgs.ipython
    pythonVersion.pkgs.black
    pythonVersion.pkgs.isort
  ] ++ extraPackages;

  shellHook = ''
    ${promptHook}
    echo "${message}"
  '';
}

