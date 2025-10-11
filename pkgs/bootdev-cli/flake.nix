{
  description = "Boot.dev CLI package (flake-only setup)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system} = {
        bootdev-cli = pkgs.callPackage ./bootdev-cli.nix {};
        default = self.packages.${system}.bootdev-cli;
      };
    };
}

