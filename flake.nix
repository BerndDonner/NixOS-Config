{
  description = "Bernd’s NixOS + Home-Manager configuration (fully flake-only)";

  inputs = {
    # 🧩 Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-2605.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-2605.url = "github:nix-community/home-manager/release-26.05";
    home-manager-2605.inputs.nixpkgs.follows = "nixpkgs-2605";

    # ✍️ Editor (pinned via flake.lock)
    helix.url = "github:helix-editor/helix";

    bootdev-cli.url = "path:./pkgs/bootdev-cli";
    bootdev-cli.flake = false;

    context.url = "path:./pkgs/context";
    context.flake = false;

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-2605";
  };

  outputs = {self, nixpkgs, nixpkgs-unstable, nixpkgs-2605, home-manager, home-manager-2605, helix, bootdev-cli, context, disko, ... }@inputs:
    let
      system = "x86_64-linux";

      # Overlay: make pkgs.unstable available
      overlayUnstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (final.stdenv.hostPlatform) system;
          config = final.config;
        };
      };

      # Overlay: pygame mit AVX2
      overlayPygameAvx2 = import ./overlays/pygame-avx2.nix;

      # Unified pkgs with overlay applied
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlayUnstable overlayPygameAvx2 ];
      };

      commonHomeManagerModule = {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        nixpkgs.overlays = [ overlayUnstable overlayPygameAvx2 ];

        home-manager.users.bernd = import ./home-manager/home.nix;
      };

      commonSystemModules = [
        ./modules/bash.nix
        ./modules/starship.nix
        ./modules/nordvpn.nix
        home-manager.nixosModules.home-manager
        commonHomeManagerModule
      ];
    in {
      # ------------------------------------------------------------------------
      # 1️⃣ NixOS + Home-Manager configurations
      # ------------------------------------------------------------------------
      nixosConfigurations = {
        kitty = nixpkgs.lib.nixosSystem {
          inherit system;
          modules =
            [
              ./hosts/kitty/configuration.nix
              ./modules/virtualisation.nix
            ]
            ++ commonSystemModules;
        };

        tracy = nixpkgs.lib.nixosSystem {
          inherit system;
          modules =
            [
              ./hosts/tracy/configuration.nix
            ]
            ++ commonSystemModules;
        };

        cloud = nixpkgs-2605.lib.nixosSystem {
          system = "x86_64-linux";
          modules =
            [
              disko.nixosModules.disko
              ./hosts/cloud/disko.nix
              ./hosts/cloud/configuration.nix

              ./modules/bash.nix
              ./modules/starship.nix

              home-manager-2605.nixosModules.home-manager

              {
                # Helix etc. verwenden pkgs.unstable
                nixpkgs.overlays = [ overlayUnstable ];

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = { inherit inputs; };

                home-manager.users.bleau =
                  import ./home-manager/hosts/cloud.nix;
              }
            ];
        };
      };

      # ------------------------------------------------------------------------
      # 3️⃣ Custom packages from derivations
      # ------------------------------------------------------------------------
      packages.${system} = {
        bootdev-cli = pkgs.callPackage ./pkgs/bootdev-cli/bootdev-cli.nix { };
        context = pkgs.callPackage ./pkgs/context/luametatex.nix { };
        nordvpn = pkgs.callPackage ./pkgs/nordvpn/nordvpn.nix { };
      };

      # ------------------------------------------------------------------------
      # 4️⃣ Reusable devShells
      # ------------------------------------------------------------------------
      devShells.${system} = {
        python = (import ./lib/python-develop.nix) { inherit pkgs; };
        pythonVenv = (import ./lib/python-venv-develop.nix) { inherit pkgs; };
      };

      # ------------------------------------------------------------------------
      # 5️⃣ Overlay exports
      # ------------------------------------------------------------------------
      overlays = {
        unstable = overlayUnstable;
        pygame-avx2 = overlayPygameAvx2;
      };
    };
}
