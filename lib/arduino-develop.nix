# arduino-base-shell.nix
{ pkgs
, flakeLockPath ? null  # Required when checkInputs is non-empty
, tioPackage ? pkgs.tio  # central nixos-config passes its pinned fork
, symbol ? "📟"
, message ? "📟 Arduino development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ "nixos-config" ]         # optional inputs to verify
, extraPackages ? [ ]
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  # Non-blocking update warning (on by default for consuming projects)
  updateWarningHook = import ./devshell-update.nix {
    inherit pkgs inputs flakeLockPath checkInputs;
  };
in
pkgs.mkShell {
  name = "arduino-env";

  shell = pkgs.bashInteractive;

  # Base toolchain for Arduino C/C++ development
  packages = with pkgs; [
    arduino-cli             # command-line interface for sketches & board management
    avrdude                 # upload tool for AVR boards
    tioPackage              # pinned yabu76/tio fork from NixOS-Config
    jq                      # useful for parsing Arduino CLI JSON output
  ] ++ extraPackages ++ [ (import ./devflake-update.nix { inherit pkgs; }) ];

  shellHook = ''
    ${secretHook}
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH
    ${promptHook}
    ${updateWarningHook}
    echo "${message}"
    ${extraShellHook}
  '';
}

