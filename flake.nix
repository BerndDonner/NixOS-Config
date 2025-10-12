{
  description = "Bernd’s NixOS + Home-Manager configuration (fully flake-only)";

  inputs = {
    # 🧩 Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    shared-nixpkgs.follows = "nixpkgs";
    
    # 🧱 Local flakes
    lib.url         = "path:./lib";
    bootdev-cli.url = "path:./pkgs/bootdev-cli";
    context.url     = "path:./pkgs/context";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lib, bootdev-cli, context, ... }@inputs:
  let
    system = "x86_64-linux";

    # Overlay: make pkgs.unstable available
    overlayUnstable = final: prev: {
      unstable = import nixpkgs-unstable { inherit system; };
    };

    # Unified pkgs with overlay applied
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ overlayUnstable ];
    };
  in {
    # --------------------------------------------------------------------------
    # 1️⃣ NixOS + Home-Manager configuration
    # --------------------------------------------------------------------------
    nixosConfigurations.tracy = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          nixpkgs.overlays = [ overlayUnstable ];

          home-manager.users.bernd = { config, pkgs, lib, ... }:
            import ./home-manager/home.nix {
              inherit config pkgs lib inputs;
            };
        }
      ];
    };

    # --------------------------------------------------------------------------
    # 2️⃣ Shared library (from local flake)
    # --------------------------------------------------------------------------
    lib = lib.lib;

    # --------------------------------------------------------------------------
    # 3️⃣ Custom packages (from sub-flakes)
    # --------------------------------------------------------------------------
    packages.${system} = {
      inherit (bootdev-cli.packages.${system}) bootdev-cli;
      inherit (context.packages.${system}) context;
    };

    # --------------------------------------------------------------------------
    # 4️⃣ Reusable devShells
    # --------------------------------------------------------------------------
    devShells.${system} = {
      python     = self.lib.python-develop { inherit pkgs; };
      pythonVenv = self.lib.python-venv-develop { inherit pkgs; };
    };

    # --------------------------------------------------------------------------
    # 5️⃣ Overlay exports
    # --------------------------------------------------------------------------
    overlays.unstable = overlayUnstable;
  };
}

