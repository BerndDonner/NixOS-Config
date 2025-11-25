{
  description = "Bernd’s NixOS + Home-Manager configuration (fully flake-only)";

  inputs = {
    # 🧩 Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    # 🧱 Local flakes
    lib.url         = "path:./lib";
    lib.flake = false;
    bootdev-cli.url = "path:./pkgs/bootdev-cli";
    bootdev-cli.flake = false;
    context.url     = "path:./pkgs/context";
    context.flake = false;
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, lib, bootdev-cli, context, ... }@inputs:
  let
    system = "x86_64-linux";

    # Overlay: make pkgs.unstable available
    overlayUnstable = final: prev: {
      unstable = import nixpkgs-unstable { inherit system; };
    };
    # Overlay: pygame mit AVX2
    overlayPygameAvx2 = import ./overlays/pygame-avx2.nix;

    # Unified pkgs with overlay applied
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ overlayUnstable overlayPygameAvx2 ];
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
        ./modules/nordvpn.nix

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          nixpkgs.overlays = [ overlayUnstable overlayPygameAvx2 ];

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
    # 3️⃣ Custom packages from derivations
    # --------------------------------------------------------------------------
    packages.${system} = {
      bootdev-cli = pkgs.callPackage ./pkgs/bootdev-cli/bootdev-cli.nix { };
      context     = pkgs.callPackage ./pkgs/context/luametatex.nix { };
      nordvpn     = pkgs.callPackage ./pkgs/nordvpn/nordvpn.nix { };
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
    overlays = {
      unstable    = overlayUnstable;
      pygame-avx2 = overlayPygameAvx2;
    };
  };
}
