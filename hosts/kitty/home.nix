{ pkgs, ... }:

{
  imports = [
    ../../home-manager/modules/basics.nix
    ../../home-manager/modules/packages.nix
    ../../home-manager/modules/ssh.nix
    ../../home-manager/modules/git.nix
    ../../home-manager/modules/git-desktop.nix
    ../../home-manager/modules/tmux.nix
    ../../home-manager/modules/vim.nix
    ../../home-manager/modules/helix.nix
  ];

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    blender
  ];

  programs.home-manager.enable = true;
}
