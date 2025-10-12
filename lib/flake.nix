{
  description = "Reusable Nix library functions for Bernd’s NixOS configuration";

  inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      lib = rec {
        # === Dev shell hooks ===
        prompt-hook         = import ./prompt-hook.nix;
        update-warning-hook = import ./update-warning-hook.nix;

        # === Base dev-shell definitions ===
        python-develop      = import ./python-develop.nix;
        python-venv-develop = import ./python-venv-develop.nix;
      };

      # Optional: small placeholder package for discoverability
      packages.${system}.default = pkgs.runCommand "lib-placeholder" {} ''
        mkdir -p $out
        echo "This flake exposes Nix library functions under .lib, not build artifacts." > $out/README.txt
      '';
    };
}
