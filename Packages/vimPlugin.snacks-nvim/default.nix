# default.nix
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.11";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in
{
  vimPlugin.snacks-nvim = pkgs.callPackage ./snacks-nvim.nix { };
}

