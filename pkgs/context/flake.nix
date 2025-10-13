{
  description = "ConTeXt (LMTX / LuaMetaTeX) package flake for Bernd’s NixOS setup";

  inputs = {
    nixos-config.url = "github:BerndDonner/NixOS-Config";
    nixpkgs.follows = "nixos-config/nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-config, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nixos-config.overlays.unstable ];
      };
    in {
      # ------------------------------------------------------------------------
      # 🧱 Packages
      # ------------------------------------------------------------------------
      packages.${system} = {
        luametatex = pkgs.callPackage ./luametatex.nix {};
        default = self.packages.${system}.luametatex;
      };

      # ------------------------------------------------------------------------
      # 🧩 Metadata
      # ------------------------------------------------------------------------
      meta = {
        description = "ConTeXt LuaMetaTeX engine packaged via Nix flake";
        homepage = "https://wiki.contextgarden.net";
        maintainers = [ "Bernd Donner" ];
        license = pkgs.lib.licenses.gpl3Plus;
      };
    };
}

