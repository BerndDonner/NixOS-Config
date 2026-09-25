# c-develop.nix
{ pkgs
, flakeLockPath ? ./flake.lock   # fallback for same-directory usage
, symbol ? ""
, compiler ? pkgs.gcc
, message ? " C development environment ready"
, inputs ? null                  # optional flake inputs
, checkInputs ? [ ]              # optional inputs to verify
, extraPackages ? [ ]
, extraNativeBuildInputs ? [ ]
, extraBuildInputs ? [ ]
, extraShellHook ? ""
}:

let
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
      "";
in
pkgs.mkShell {
  name = "c-development";

  shell = pkgs.bashInteractive;

  # Tools needed while configuring/building C projects.
  nativeBuildInputs = with pkgs; [
    compiler
    pkg-config
    gnumake
    cmake
    meson
    ninja
    git
  ] ++ extraNativeBuildInputs;

  # Project-specific libraries belong here so their setup hooks expose
  # include paths, library paths and pkg-config metadata.
  buildInputs = extraBuildInputs;

  # Interactive development/debugging tools.
  packages = with pkgs; [
    gdb
    clang-tools
    jq
    curl
  ] ++ extraPackages;

  shellHook = ''
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH

    ${promptHook}
    ${updateWarningHook}
    ${extraShellHook}

    echo "${message}"
  '';
}
