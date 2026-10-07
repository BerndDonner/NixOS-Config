
# python-base-shell.nix
{ pkgs
, flakeLockPath ? ./flake.lock   # fallback for same-directory usage
, symbol ? "🐍"
, pythonVersion ? pkgs.python3
, pythonPackages ? (_: [ ])  # importable Python packages, e.g. ps: [ ps.pyyaml ]
, extraPackages ? [ ]          # non-Python tools/programs added to the shell
, message ? "🐍 Python development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ ]         # optional inputs to verify
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  pythonEnv = pythonVersion.withPackages (ps:
    [
      ps.pip
      ps.setuptools
      ps.wheel
      ps.ipython
      ps.black
      ps.isort
    ]
    ++ pythonPackages ps
  );

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

  packages = [
    pythonEnv
    pkgs.jq
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
