# arduino-base-shell.nix
{ pkgs
, flakeLockPath ? null  # Required when checkInputs is non-empty
, symbol ? "📟"
, message ? "📟 Arduino development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ ]         # optional inputs to verify
, extraPackages ? [ ]
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  # Update warning hook (optional)
  updateWarningHook =
    if checkInputs == [ ] then
      ""
    else if inputs == null then
      throw "mkArduinoDevShell: checkInputs requires inputs to be provided."
    else if flakeLockPath == null then
      throw "mkArduinoDevShell: checkInputs requires flakeLockPath (e.g. flakeLockPath = ./flake.lock; in the calling flake)."
    else
      import ./update-warning-hook.nix {
        inherit inputs;
        inherit checkInputs;
        inherit flakeLockPath;
        symbol = "⚠";
      };
in
pkgs.mkShell {
  name = "arduino-env";

  shell = pkgs.bashInteractive;

  # Base toolchain for Arduino C/C++ development
  packages = with pkgs; [
    arduino-cli             # command-line interface for sketches & board management
    avrdude                 # upload tool for AVR boards
    picocom                 # simple serial monitor
    minicom                 # advanced serial terminal
    jq                      # useful for parsing Arduino CLI JSON output
  ] ++ extraPackages;

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

