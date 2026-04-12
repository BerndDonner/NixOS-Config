{ config, pkgs, lib, osConfig, inputs, ... }:

{
  imports = [
    ./modules/basics.nix
    ./modules/packages.nix
    ./modules/ssh.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/vim.nix
    ./modules/helix.nix
    (./hosts + "/${osConfig.networking.hostName}.nix")
  ];

  programs.home-manager.enable = true;
}
