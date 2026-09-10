{ pkgs, ... }:

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
  ];

  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    cudatoolkit

    (blender.override {
      cudaSupport = true;
    })
  ];

  programs.home-manager.enable = true;
}
