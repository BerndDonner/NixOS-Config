# c-develop.nix
{ pkgs
, flakeLockPath ? null  # Required when checkInputs is non-empty
, symbol ? ""
, compiler ? pkgs.gcc
, message ? " C development environment ready"
, inputs ? null                  # optional flake inputs
, checkInputs ? [ ]              # optional inputs to verify
, extraPackages ? [ ]
, extraNativeBuildInputs ? [ ]
, extraBuildInputs ? [ ]
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  updateWarningHook =
    if checkInputs == [ ] then
      ""
    else if inputs == null then
      throw "mkCDevShell: checkInputs requires inputs to be provided."
    else if flakeLockPath == null then
      throw "mkCDevShell: checkInputs requires flakeLockPath (e.g. flakeLockPath = ./flake.lock; in the calling flake)."
    else
      import ./update-warning-hook.nix {
        inherit inputs;
        inherit checkInputs;
        inherit flakeLockPath;
        symbol = "⚠️";
      };
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
    ${secretHook}
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export PATH=${pkgs.bashInteractive}/bin:$PATH

    ${promptHook}
    ${updateWarningHook}
    ${extraShellHook}

    echo "${message}"
  '';
}
