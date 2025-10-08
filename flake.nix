{
  description = "Bernd’s NixOS + Home-Manager configuration with reusable packages and library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
  let
    system = "x86_64-linux";

    # Global overlay: makes pkgs.unstable available everywhere
    overlayUnstable = (final: prev: {
      unstable = import nixpkgs-unstable { inherit system; };
    });

    # Unified pkgs for packages/devShells (overlay applied once)
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ overlayUnstable ];
    };
  in {

    # --------------------------------------------------------------------------
    # 1️⃣ NixOS and Home-Manager configuration
    # --------------------------------------------------------------------------
    nixosConfigurations.tracy = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # home-manager.backupFileExtension = "hm-backup"; #Debugging

          # Apply the same global overlay inside the NixOS eval
          nixpkgs.overlays = [ overlayUnstable ];

          home-manager.users.bernd = { config, pkgs, lib, ... }:
            import ./home-manager/home.nix { inherit config pkgs lib inputs; };
        }
      ];
    };

    # --------------------------------------------------------------------------
    # 2️⃣ Shared library functions (promptHook, python shells, etc.)
    # --------------------------------------------------------------------------
    lib = import ./lib;

    # --------------------------------------------------------------------------
    # 3️⃣ Custom packages (derivations you maintain yourself)
    # --------------------------------------------------------------------------
    packages.${system} = {
      context = pkgs.callPackage ./pkgs/context { };
      # add more custom packages here later
    };

    # --------------------------------------------------------------------------
    # 4️⃣ Reusable devShells
    # --------------------------------------------------------------------------
    devShells.${system} = {
      python     = self.lib.python-develop { inherit pkgs; };
      pythonVenv = self.lib.python-venv-develop { inherit pkgs; };
    };
  };
}

