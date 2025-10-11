{
  description = "Reusable Nix library functions for Bernd’s NixOS configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      lib = rec {
        prompt-hook         = import ./prompt-hook.nix;
        python-develop      = import ./python-develop.nix;
        python-venv-develop = import ./python-venv-develop.nix;
      };

      # Optional: expose for nix repl / flake show
      packages.${system}.default = pkgs.runCommand "lib-placeholder" {} ''
        mkdir -p $out
        echo "This flake exposes library functions under .lib, not build artifacts." > $out/README.txt
      '';
    };
}

