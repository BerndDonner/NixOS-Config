{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/home-manager/basics.nix
    ../../modules/home-manager/packages.nix
    ../../modules/home-manager/ssh.nix
    ../../modules/home-manager/vault-links.nix
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

  # Kitty uses KWallet for KDE/NetworkManager secrets. Only the
  # encrypted wallet files live in the vault, not in the Nix store.
  home.file.".local/share/kwalletd".source =
    config.lib.file.mkOutOfStoreSymlink "/secrets/kwallet";

  # On the first switch, safely hand over the existing direct link to
  # Home Manager without touching the wallet contents inside /secrets.
  home.activation.adoptManualKWalletLink =
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      existing="$HOME/.local/share/kwalletd"
      if [ -L "$existing" ] &&
         [ "$(readlink "$existing")" = "/secrets/kwallet" ]; then
        rm -- "$existing"
      fi
    '';

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    blender
  ];

  programs.home-manager.enable = true;
}
