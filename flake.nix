{
  description = "Bernd’s NixOS + Home-Manager configuration with reusable packages and library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: {
    # --------------------------------------------------------------------------
    # 1️⃣ NixOS and Home-Manager configuration
    # --------------------------------------------------------------------------
    nixosConfigurations.tracy = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # home-manager.backupFileExtension = "hm-backup"; #Debugging

          nixpkgs.overlays = [
            (final: prev: {
              unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
            })
          ];

          home-manager.users.bernd = import ./home-manager/home.nix;
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
    packages.x86_64-linux = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      context = pkgs.callPackage ./pkgs/context { };
      # add more custom packages here later
    };

    # --------------------------------------------------------------------------
    # 4️⃣ Reusable devShells
    # --------------------------------------------------------------------------
    devShells.x86_64-linux = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in {
      python     = self.lib.python-develop { inherit pkgs; };
      pythonVenv = self.lib.python-venv-develop { inherit pkgs; };
    };
  };
}

