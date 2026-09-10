{ pkgs, ... }:

{
  imports = [
    ../../home-manager/modules/git.nix
    ../../home-manager/modules/tmux.nix
    ../../home-manager/modules/vim.nix
    ../../home-manager/modules/helix.nix
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
