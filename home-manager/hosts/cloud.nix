{ pkgs, ... }:

{
  imports = [
    ../profiles/cli.nix
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
