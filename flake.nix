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
    # Productive ConTeXt source is pinned by the main flake.lock.
    # Intentionally keep revision 5751e396 until the local Math/Glue patch
    # has been reviewed and retested against a newer upstream revision.
    # Keeping this separate from texmf.zip is intentional: the Git tree
    # does not contain the bootstrap/font texmf tree needed by ConTeXt.
    context-src = {
      url = "github:contextgarden/context";
      flake = false;
    };

    # Two independently pinned comparison sources. These commits do not move
    # when the productive context-src is updated.
    context-2024-src = {
      url = "github:contextgarden/context/0d2ec448a05c3cf7e83d79ad62eb485f48464872";
      flake = false;
    };

    context-upstream-src = {
      url = "github:contextgarden/context/445076e571b5d12df19bd1f0f60536563888078c";
      flake = false;
    };

    # Both the filter and Vim modules come from this repository. Its upstream
    # revision contains the writable-directory fix for LMTX (t-filter.mkxl).
    filter-src = {
      url = "github:adityam/filter/ca120d80cb455826ef97e97b32c2abf5ecc82ce2";
      flake = false;
    };

    # -------------------------------------------------------------------------
    # Pinned serial terminal fork, independently updateable:
    #   nix flake update tio-src
    tio-src = {
      url = "github:yabu76/tio/master_this_fork";
      flake = false;
    };

    # -------------------------------------------------------------------------
    # External modules / applications
    # -------------------------------------------------------------------------
    disko.url =
      "github:nix-community/disko";

    disko.inputs.nixpkgs.follows =
      "nixpkgs";

    # Helix with Steel plugin system (PR #8675)
    helix = {
      url = "github:mattwparas/helix/steel-event-system";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    steel.url = "github:mattwparas/steel";
    steel.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
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

      # One parametrized package builder; independent revisions can choose
      # their own patch stacks without changing the native/sandbox machinery.
      # The external filter/Vim modules are fixed by a separate flake input.
      mkContextPackage = packageSet: args:
        packageSet.callPackage ./pkgs/context/luametatex.nix (
          { moduleFilter = inputs.filter-src; } // args
        );

      # The productive DEFAULT, including for all consumers of the exported
      # overlay, is our patched 2026-10-25 engine (not unpatched upstream).
      overlayContext = final: prev: {
        contextLmtx = mkContextPackage final {
          contextSource = inputs.context-src;
          contextRevision = inputs.context-src.rev or "unknown";
          enginePatches = [
            ./pkgs/context/patches/luametatex-math-glue-noautobreak.patch
          ];
          localVersion = "2026.10.25-p1";
          patchLabel = "math-glue-noautobreak";
        };
      };

      overlayTioFork = final: prev: {
        tio-fork = prev.tio.overrideAttrs (_old: {
          pname = "tio-fork";
          version = "3.9-unstable-${builtins.substring 0 8 (inputs.tio-src.rev or "unknown")}";
          src = inputs.tio-src;
        });
      };

      # Package set used by this flake's own packages and devShells.
      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          overlayUnstable
          overlayPygameAvx2
          overlayContext
          overlayTioFork
        ];
      };

      # Explicitly unpatched reference builds. No .override of the patched
      # default: their enginePatches lists are empty by construction.
      context2024 = mkContextPackage pkgs {
        contextSource = inputs.context-2024-src;
        contextRevision = inputs.context-2024-src.rev or "unknown";
        enginePatches = [ ];
      };

      contextUpstream = mkContextPackage pkgs {
        contextSource = inputs.context-upstream-src;
        contextRevision = inputs.context-upstream-src.rev or "unknown";
        enginePatches = [ ];
      };

    in
    {
      # -----------------------------------------------------------------------
      # NixOS hosts
      # -----------------------------------------------------------------------
      nixosConfigurations = {
        # ---------------------------------------------------------------------
        # kitty
        # ---------------------------------------------------------------------
        kitty = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/kitty/configuration.nix

            ./modules/nixos/bash.nix
            ./modules/nixos/starship.nix
            ./modules/nixos/nordvpn.nix
            ./modules/nixos/virtualisation.nix
            ./modules/nixos/brother-hl2140.nix

            home-manager.nixosModules.home-manager

            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayPygameAvx2
                overlayContext
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
        # ---------------------------------------------------------------------
        tracy = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./hosts/tracy/configuration.nix
            ./modules/nixos/bash.nix
            ./modules/nixos/starship.nix
            ./modules/nixos/nordvpn.nix
            ./modules/nixos/virtualisation.nix
            ./modules/nixos/brother-hl2140.nix

            home-manager.nixosModules.home-manager

            {
              nixpkgs.overlays = [
                overlayUnstable
                overlayPygameAvx2
                overlayContext
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

            ./modules/nixos/bash.nix
            ./modules/nixos/starship.nix
            ./modules/nixos/forgejo.nix

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
      # Public flake API (only three distinct ConTeXt engines):
      #   .#context                 patched productive default, 2026.10.25-p1
      #   .#context-2024            historical unpatched reference
      #   .#context-upstream        unpatched 445076e5 reference
      #   .#context-sandbox-patched portable archive of the default
      #   .#context-docs            documentation archive of the default
      # -----------------------------------------------------------------------
      packages.${system} = {
        bootdev-cli =
          pkgs.callPackage ./pkgs/bootdev-cli/bootdev-cli.nix { };

        # This is *also* pkgs.contextLmtx from overlays.context.
        context = pkgs.contextLmtx;
        context-2024 = context2024;
        context-upstream = contextUpstream;

        # Exactly one portable engine: the productive, patched default.
        context-sandbox-patched = pkgs.callPackage ./pkgs/context/sandbox.nix {
          contextPackage = pkgs.contextLmtx;
        };

        context-docs = pkgs.callPackage ./pkgs/context/docs.nix {
          contextPackage = pkgs.contextLmtx;
          contextRevision = inputs.context-src.rev or "unknown";
        };

        nordvpn =
          pkgs.callPackage ./pkgs/nordvpn/nordvpn.nix { };

        tio-fork = pkgs.tio-fork;
        devflake-update = import ./lib/devflake-update.nix { inherit pkgs; };
      };

      # Python is only needed for the bundle integrity verifier, not as a
      # system runtime dependency of ConTeXt.
      devShells.${system}.context = pkgs.mkShellNoCC {
        packages = [ pkgs.python3 ];
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
        context = overlayContext;
        tio-fork = overlayTioFork;
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
      #   nixos-config.lib.mkArduinoDevShell
      #   nixos-config.lib.mkCDevShell
      #   nixos-config.lib.mkElectronDevShell
      # -----------------------------------------------------------------------
      lib = {
        mkSecretShellHook =
          import ./lib/secret-shell-hook.nix;

        mkArduinoDevShell = args:
          import ./lib/arduino-develop.nix (
            { tioPackage = pkgs.tio-fork; } // args
          );

        mkCDevShell =
          import ./lib/c-develop.nix;

        mkContextDevShell =
          import ./lib/context-dev.nix;

        mkElectronDevShell =
          import ./lib/electron-develop.nix;

        mkPythonDevShell =
          import ./lib/python-develop.nix;

        mkPythonVenvDevShell =
          import ./lib/python-venv-develop.nix;
      };
    };
}
