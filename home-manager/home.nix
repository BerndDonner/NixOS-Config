{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./modules/basics.nix
    ./modules/packages.nix
    ./modules/bash.nix
    ./modules/ssh.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/vim.nix
    ./modules/helix.nix
    ./modules/starship.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
