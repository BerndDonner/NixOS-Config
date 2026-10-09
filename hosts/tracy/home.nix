{ config, pkgs, ... }:

{
  imports = [
    ../../modules/home-manager/basics.nix
    ../../modules/home-manager/packages.nix
    ../../modules/home-manager/ssh.nix
    ../../modules/home-manager/git.nix
    ../../modules/home-manager/git-desktop.nix
    ../../modules/home-manager/tmux.nix
    ../../modules/home-manager/vim.nix
    ../../modules/home-manager/helix.nix
    ../../modules/home-manager/zk.nix
  ];

  donner.helix = {
    developmentTools = true;
    steelForge = true;
  };

  # Keep tracy's own private age identity inside the LUKS-backed vault.
  # Home Manager exposes it at the standard path without copying it to the Nix store.
  home.file.".config/sops/age/keys.txt".source =
    config.lib.file.mkOutOfStoreSymlink "/secrets/sops/age/keys.txt";

  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    cudatoolkit

    (unstable.blender.override {
      cudaSupport = true;
    })
  ];

  programs.home-manager.enable = true;
}
