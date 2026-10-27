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

    # Scope serial monitor source. Scope currently requires a newer Rust than
    # the stable package set, so it is built with nixpkgs-unstable below while
    # the source itself is pinned independently in flake.lock.
    scope-rs-src = {
      url = "github:matheuswhite/scope-rs/v0.6.0";
      flake = false;
    };

    # -------------------------------------------------------------------------
    # ConTeXt source is pinned by the main flake.lock. To update only ConTeXt:
    #   nix flake update context-src
    # Nix fetches the upstream repository and records its exact rev/narHash.
    # Keeping this separate from texmf.zip is intentional: the Git tree
    # does not contain the bootstrap/font texmf tree needed by ConTeXt.
    context-src = {
      url = "github:contextgarden/context";
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

      # Scope needs Rust >= 1.92, therefore build only this package from the
      # unstable package set. The rest of the machines stays on NixOS 26.05.
      overlayScopeRs = final: prev: {
        scope-rs = prev.unstable.callPackage ./pkgs/scope-rs/scope-rs.nix {
          scopeRsSrc = inputs.scope-rs-src;
        };
      };

      # Regular, unmodified LuaMetaTeX for NixOS, Home Manager and sandbox.
      # Experimental engine patches are selected explicitly in packages.
      overlayContext = final: prev: {
        contextLmtx = final.callPackage ./pkgs/context/luametatex.nix {
          contextSource = inputs.context-src;
          contextRevision = inputs.context-src.rev or "unknown";
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
          overlayScopeRs
          overlayContext
          overlayTioFork
        ];
      };

      # Same pinned source; no experimental C patch in pkgs.contextLmtx.
      contextPatched = pkgs.contextLmtx.override {
        enginePatches = [
          ./pkgs/context/patches/luametatex-math-glue-noautobreak.patch
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
                overlayScopeRs
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
                overlayScopeRs
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
      # Public flake API:
      #
      #   nixos-config.packages.x86_64-linux.bootdev-cli
      #   nixos-config.packages.x86_64-linux.context
      #   nixos-config.packages.x86_64-linux.context-patched
      #   nixos-config.packages.x86_64-linux.context-sandbox
      #   nixos-config.packages.x86_64-linux.context-sandbox-patched
      #   nixos-config.packages.x86_64-linux.context-docs
      #   nixos-config.packages.x86_64-linux.nordvpn
      #   nixos-config.packages.x86_64-linux.scope-rs
      # -----------------------------------------------------------------------
      packages.${system} = {
        bootdev-cli =
          pkgs.callPackage ./pkgs/bootdev-cli/bootdev-cli.nix { };

        # Production/default stays on the unpatched upstream engine.
        context = pkgs.contextLmtx;
        context-patched = contextPatched;

        context-sandbox = pkgs.callPackage ./pkgs/context/sandbox.nix {
          contextPackage = pkgs.contextLmtx;
        };
        context-sandbox-patched = pkgs.callPackage ./pkgs/context/sandbox.nix {
          contextPackage = contextPatched;
        };

        # Optional LMTX/MkIV documentation sources, kept separate from the
        # executable sandbox. Both use the same pinned ConTeXt package.
        context-docs = pkgs.callPackage ./pkgs/context/docs.nix {
          contextPackage = pkgs.contextLmtx;
          contextRevision = inputs.context-src.rev or "unknown";
        };

        nordvpn =
          pkgs.callPackage ./pkgs/nordvpn/nordvpn.nix { };

        scope-rs = pkgs.scope-rs;
        tio-fork = pkgs.tio-fork;
        devflake-update = import ./lib/devflake-update.nix { inherit pkgs; };
      };

      # Cross-variant regression gates are independent of package and
      # sandbox installation tests. Both versions use one context-src pin.
      checks.${system}.context-math-nobreak = pkgs.runCommand
        "context-math-nobreak-regression"
        {
          nativeBuildInputs = [ pkgs.coreutils pkgs.poppler-utils pkgs.python3 ];
        }
        ''
          CONTEXT_TEST_CACHE_ROOT="$TMPDIR" \
            bash ${./pkgs/context/tests/math-nobreak}/compare.sh \
              ${pkgs.contextLmtx}/bin/context \
              ${contextPatched}/bin/context \
              "$out"
        '';

      # Broader behavioral gate for math penalties and glue option combinations.
      # Kept separate from the package builds and from the narrow 12-case check.
      checks.${system}.context-math-nobreak-extended = pkgs.runCommand
        "context-math-nobreak-extended-regression"
        {
          nativeBuildInputs = [ pkgs.coreutils pkgs.poppler_utils pkgs.python3 ];
        }
        ''
          CONTEXT_TEST_CACHE_ROOT="$TMPDIR" \
            bash ${./pkgs/context/tests/math-nobreak/extended}/compare.sh \
              ${pkgs.contextLmtx}/bin/context \
              ${contextPatched}/bin/context \
              "$out"
        '';

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
