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

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    blender
  ];

  programs.home-manager.enable = true;
}
