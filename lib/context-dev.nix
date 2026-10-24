# Reusable ConTeXt development shell. The LMTX package is built by the
# NixOS-Config flake; no TeX engine is installed globally on the hosts.
{ pkgs
, contextPackage
, symbol ? "📄"
, message ? "📄 ConTeXt development shell ready"
}:
let
  promptHook = import ./prompt-hook.nix { inherit symbol; };
in
pkgs.mkShellNoCC {
  name = "context-development";
  packages = [ contextPackage pkgs.gnumake ];
  shellHook = ''
    ${promptHook}
    echo "${message}"
  '';
}
