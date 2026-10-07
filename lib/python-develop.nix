
# python-base-shell.nix
{ pkgs
, flakeLockPath ? ./flake.lock   # fallback for same-directory usage
, symbol ? "🐍"
, pythonVersion ? pkgs.python3
, extraPackages ? [ ]
, message ? "🐍 Python development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ ]         # optional inputs to verify
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  updateWarningHook =
    if inputs != null && checkInputs != [ ] then
      import ./update-warning-hook.nix {
        inherit inputs;
        inherit checkInputs;
        inherit flakeLockPath;
        symbol = "⚠️";
      }
    else
      ""; # no-op if not provided
in
pkgs.mkShell {
  name = "python-env";

  shell = pkgs.bashInteractive;

  packages = with pkgs; [
    pythonVersion
    pythonVersion.pkgs.pip
    pythonVersion.pkgs.setuptools
    pythonVersion.pkgs.wheel
    pythonVersion.pkgs.ipython
    pythonVersion.pkgs.black
    pythonVersion.pkgs.isort
    jq
  ] ++ extraPackages;

  shellHook = ''
    ${secretHook}
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH
    ${promptHook}
    ${updateWarningHook}
    ${extraShellHook}
    echo "${message}"
  '';
}
