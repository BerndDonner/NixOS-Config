{
  description = "Bernd's NixOS configuration";

  inputs = {
    # -------------------------------------------------------------------------
    # Current NixOS release
    #
    # This is also the public nixpkgs input used by external development flakes:
    #
    #   nixpkgs.follows = "nixos-config/nixpkgs";
    # -------------------------------------------------------------------------
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager.url =
      "github:nix-community/home-manager/release-26.05";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Packages deliberately taken from unstable.
    nixpkgs-unstable.url =
      "github:nixos/nixpkgs/nixpkgs-unstable";

    # -------------------------------------------------------------------------
    # TEMPORARY: NixOS 25.11
    #
    # Remove these two inputs after kitty and tracy have been migrated to 26.05.
    # -------------------------------------------------------------------------
    nixpkgs-2511.url =
      "github:nixos/nixpkgs/nixos-25.11";

    home-manager-2511.url =
      "github:nix-community/home-manager/release-25.11";

    home-manager-2511.inputs.nixpkgs.follows =
      "nixpkgs-2511";

    # -------------------------------------------------------------------------
    # External modules / applications
    # -------------------------------------------------------------------------
    disko.url =
      "github:nix-community/disko";

    disko.inputs.nixpkgs.follows =
      "nixpkgs";

    # Helix with Steel plugin system (PR #8675)
    helix.url = "github:mattwparas/helix/steel-event-system";
    steel.url = "github:mattwparas/steel";
    steel.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-2511,
      nixpkgs-unstable,
      home-manager,
      home-manager-2511,
      disko,
      ...
    }:
    let
      # Used for packages and development shells.
      #
      # NixOS hosts specify their architecture explicitly in their host
      # definition below.
      system = "x86_64-linux";

      # -----------------------------------------------------------------------
      # Overlays
      # -----------------------------------------------------------------------
      overlayUnstable = final: prev: {
        unstable = import nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config = final.config;
        };
      };

      overlayPygameAvx2 =
        import ./overlays/pygame-avx2.nix;

      # Package set used by this flake's own packages and devShells.
      #
      # This deliberately uses the current NixOS release, not the temporary
      # 25.11 compatibility input.
      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          overlayUnstable
          overlayPygameAvx2
        ];
      };
    in
    {
      # -----------------------------------------------------------------------
      # NixOS hosts
      # -----------------------------------------------------------------------
      nixosConfigurations = {
        # ---------------------------------------------------------------------
        # kitty
        #
        # TEMPORARY: still on NixOS 25.11.
        # ---------------------------------------------------------------------
        kitty = nixpkgs-2511.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/kitty/configuration.nix

            ./modules/bash.nix
            ./modules/starship.nix
            ./modules/nordvpn.nix
            ./modules/virtualisation.nix

            home-manager-2511.nixosModules.home-manager

            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayPygameAvx2
              ];

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs;
              };

              home-manager.users.bernd =
                import ./hosts/kitty/home.nix;
            }
          ];
        };

        # ---------------------------------------------------------------------
        # tracy
        #
        # TEMPORARY: still on NixOS 25.11.
        # ---------------------------------------------------------------------
        tracy = nixpkgs-2511.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/tracy/configuration.nix

            ./modules/bash.nix
            ./modules/starship.nix
            ./modules/nordvpn.nix

            home-manager-2511.nixosModules.home-manager

            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayPygameAvx2
              ];

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs;
              };

              home-manager.users.bernd =
                import ./hosts/tracy/home.nix;
            }
          ];
        };

        # ---------------------------------------------------------------------
        # cloud
        #
        # NixOS 26.05, CLI/server system.
        # ---------------------------------------------------------------------
        cloud = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/cloud/configuration.nix

            disko.nixosModules.disko
            ./hosts/cloud/disko.nix

            ./modules/bash.nix
            ./modules/starship.nix

            home-manager.nixosModules.home-manager

            {
              nixpkgs.overlays = [
                overlayUnstable
              ];

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = {
                inherit inputs;
              };

              home-manager.users.bleau =
                import ./hosts/cloud/home.nix;
            }
          ];
        };
      };

      # -----------------------------------------------------------------------
      # Packages
      #
      # Public flake API:
      #
      #   nixos-config.packages.x86_64-linux.bootdev-cli
      #   nixos-config.packages.x86_64-linux.context
      #   nixos-config.packages.x86_64-linux.nordvpn
      # -----------------------------------------------------------------------
      packages.${system} = {
        bootdev-cli =
          pkgs.callPackage ./pkgs/bootdev-cli/bootdev-cli.nix { };

        context =
          pkgs.callPackage ./pkgs/context/luametatex.nix { };

        nordvpn =
          pkgs.callPackage ./pkgs/nordvpn/nordvpn.nix { };
      };

      # -----------------------------------------------------------------------
      # Reusable overlays
      #
      # Public API used by external development flakes, e.g.:
      #
      #   nixos-config.overlays.unstable
      #   nixos-config.overlays.pygame-avx2
      # -----------------------------------------------------------------------
      overlays = {
        unstable = overlayUnstable;
        pygame-avx2 = overlayPygameAvx2;
      };

      # -----------------------------------------------------------------------
      # Reusable development helpers
      #
      # Public API for external development flakes.
      #
      # Instead of:
      #
      #   import (nixos-config + "/lib/python-develop.nix")
      #
      # external flakes can use:
      #
      #   nixos-config.lib.mkPythonDevShell
      # -----------------------------------------------------------------------
      lib = {
        mkPythonDevShell =
          import ./lib/python-develop.nix;

        mkPythonVenvDevShell =
          import ./lib/python-venv-develop.nix;
      };
    };
}
