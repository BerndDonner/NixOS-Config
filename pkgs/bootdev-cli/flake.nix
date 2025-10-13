{
  description = "Boot.dev CLI package (flake-only setup)";

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
      packages.${system} = {
        bootdev-cli = pkgs.callPackage ./bootdev-cli.nix {};
        default = self.packages.${system}.bootdev-cli;
      };
    };
}

