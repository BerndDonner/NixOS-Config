{ pkgs, ... }:

{
  imports = [
    ../../modules/home-manager/git.nix
    ../../modules/home-manager/tmux.nix
    ../../modules/home-manager/vim.nix
    ../../modules/home-manager/helix.nix
  ];

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    tree
    gdu
    bottom
    rclone
  ];

  programs.home-manager.enable = true;
}
