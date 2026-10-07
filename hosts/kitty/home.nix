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

  # Keep the private age identity inside kitty's LUKS-backed /secrets vault,
  # while retaining the standard path expected by SOPS.
  home.file.".config/sops/age/keys.txt".source =
    config.lib.file.mkOutOfStoreSymlink "/secrets/sops/age/keys.txt";

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    blender
  ];

  programs.home-manager.enable = true;
}
