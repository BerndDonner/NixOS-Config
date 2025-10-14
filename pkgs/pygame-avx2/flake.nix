{
  description = "Pygame (AVX2 enabled, flake-only setup)";

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
        pygame-avx2 = pkgs.callPackage ./pygame-avx2.nix { };
        default = self.packages.${system}.pygame-avx2;
      };

      devShells.${system}.default = pkgs.mkShell {
        name = "pygame-avx2-test-shell";

        packages = with pkgs; [
          python311
          python311.pkgs.pip
          self.packages.${system}.pygame-avx2
        ];

        shellHook = ''
          echo
          echo "🧪 Pygame AVX2 testing shell"
          echo "Run: python3 -m pygame.examples.aliens"
          echo
        '';
      };
    };
}

