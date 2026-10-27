# Reusable ConTeXt development shell. The LMTX package is built by the
# NixOS-Config flake; no TeX engine is installed globally on the hosts.
{ pkgs
, contextPackage
, symbol ? "📄"
, message ? "📄 ConTeXt development shell ready"
, inputs ? null
, flakeLockPath ? null
, checkInputs ? [ "nixos-config" ]
, extraPackages ? [ ]
}:
let
  promptHook = import ./prompt-hook.nix { inherit symbol; };
  updateWarningHook = import ./devshell-update.nix {
    inherit pkgs inputs flakeLockPath checkInputs;
  };
in
pkgs.mkShellNoCC {
  name = "context-development";
  packages = [ contextPackage pkgs.gnumake (import ./devflake-update.nix { inherit pkgs; }) ] ++ extraPackages;
  shellHook = ''
    ${promptHook}
    ${updateWarningHook}
    echo "${message}"
  '';
}
