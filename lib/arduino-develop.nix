# arduino-base-shell.nix
{ pkgs
, flakeLockPath ? ./flake.lock   # fallback for same-directory usage
, symbol ? "📟"
, message ? "📟 Arduino development environment ready"
, inputs ? null             # optional flake inputs
, checkInputs ? [ ]         # optional inputs to verify
, extraPackages ? [ ]
}:

let
  promptHook = import ./prompt-hook.nix { inherit symbol; };

  # Update warning hook (optional)
  updateWarningHook =
    if inputs != null && checkInputs != [ ] then
      import ./update-warning-hook.nix {
        inherit inputs;
        inherit checkInputs;
        inherit flakeLockPath;
        symbol = "⚠";
      }
    else
      ""; # no-op if not provided
in
pkgs.mkShell {
  name = "arduino-env";

  shell = pkgs.bashInteractive;

  # Base toolchain for Arduino C/C++ development
  packages = with pkgs; [
    arduino-cli             # command-line interface for sketches & board management
    gcc-avr                 # compiler for classic AVR boards (Uno, Nano, Mega)
    avrdude                 # upload tool for AVR boards
    picocom                 # simple serial monitor
    minicom                 # advanced serial terminal
    jq                      # useful for parsing Arduino CLI JSON output
  ] ++ extraPackages;

  shellHook = ''
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH
    ${promptHook}
    ${updateWarningHook}
    echo "${message}"
  '';
}

