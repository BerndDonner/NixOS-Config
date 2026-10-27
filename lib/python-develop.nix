
# python-base-shell.nix
{ pkgs
, flakeLockPath ? null  # Required when checkInputs is non-empty
, symbol ? "🐍"
, pythonVersion ? pkgs.python3
, pythonTools ? (_: [ ])  # optional developer modules, e.g. ps: [ ps.ipython ]
, pythonPackages ? (_: [ ])  # importable Python packages, e.g. ps: [ ps.pyyaml ]
, extraPackages ? [ ]          # non-Python tools/programs added to the shell
, message ? "🐍 Python development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ "nixos-config" ]         # optional inputs to verify
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  pythonEnv = pythonVersion.withPackages (ps:
    pythonPackages ps ++ pythonTools ps
  );

  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  updateWarningHook = import ./devshell-update.nix {
    inherit pkgs inputs flakeLockPath checkInputs;
  };
in
pkgs.mkShell {
  name = "python-env";

  shell = pkgs.bashInteractive;

  packages = [
    pythonEnv
    (import ./devflake-update.nix { inherit pkgs; })
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
