{
  description = "Bernd’s NixOS + Home-Manager configuration (fully flake-only)";

  inputs = {
    # 🧩 Core inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    

    # ✍️ Editor (pinned via flake.lock)
    helix.url = "github:helix-editor/helix";

    # 🧱 Local flakes
    lib.url         = "path:./lib";
    lib.flake = false;
    bootdev-cli.url = "path:./pkgs/bootdev-cli";
    bootdev-cli.flake = false;
    context.url     = "path:./pkgs/context";
    context.flake = false;
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, helix, lib, bootdev-cli, context, ... }@inputs:
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
    nixosConfigurations.kitty = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/kitty/configuration.nix
        ./modules/bash.nix
        ./modules/starship.nix
        ./modules/nordvpn.nix
        ./modules/virtualisation.nix
        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          nixpkgs.overlays = [ overlayUnstable overlayPygameAvx2 ];

          home-manager.users.bernd =
            import ./home-manager/home.nix;
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
