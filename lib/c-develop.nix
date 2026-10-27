# c-develop.nix
{ pkgs
, flakeLockPath ? null  # Required when checkInputs is non-empty
, symbol ? ""
, compiler ? pkgs.gcc
, buildSystems ? [ "make" ] # any of make, cmake, meson, ninja
, debugTools ? [ ] # any of gdb, clang-tools
, utilityTools ? [ ] # any of git, jq, curl
, message ? " C development environment ready"
, inputs ? null                  # optional flake inputs
, checkInputs ? [ "nixos-config" ]              # optional inputs to verify
, extraPackages ? [ ]
, extraNativeBuildInputs ? [ ]
, extraBuildInputs ? [ ]
, secretSets ? [ ]
, extraShellHook ? ""
}:

let
  toolMap = {
    make = pkgs.gnumake;
    cmake = pkgs.cmake;
    meson = pkgs.meson;
    ninja = pkgs.ninja;
    gdb = pkgs.gdb;
    clang-tools = pkgs.clang-tools;
    git = pkgs.git;
    jq = pkgs.jq;
    curl = pkgs.curl;
  };
  resolveTools = names: map (name:
    if builtins.hasAttr name toolMap then builtins.getAttr name toolMap
    else throw "mkCDevShell: unknown tool: ${name}"
  ) names;
  secretHook = import ./secret-shell-hook.nix { inherit pkgs secretSets; };

  promptHook = import ./prompt-hook.nix { inherit symbol; };

  updateWarningHook = import ./devshell-update.nix {
    inherit pkgs inputs flakeLockPath checkInputs;
  };
in
pkgs.mkShell {
  name = "c-development";

  shell = pkgs.bashInteractive;

  # Tools needed while configuring/building C projects.
  nativeBuildInputs = [ compiler pkgs.pkg-config ]
    ++ resolveTools buildSystems ++ extraNativeBuildInputs;

  # Project-specific libraries belong here so their setup hooks expose
  # include paths, library paths and pkg-config metadata.
  buildInputs = extraBuildInputs;

  # Interactive development/debugging tools.
  packages = resolveTools (debugTools ++ utilityTools) ++ extraPackages
    ++ [ (import ./devflake-update.nix { inherit pkgs; }) ];

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
