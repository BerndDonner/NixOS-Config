{ config, pkgs, ... }:

{
  imports = [ ../../modules/home-manager/desktop.nix ];

  # Wallet files are stored in kitty's LUKS vault.
  home.file.".local/share/kwalletd".source =
    config.lib.file.mkOutOfStoreSymlink "/secrets/kwallet";

  home.packages = with pkgs; [ blender ];
  home.stateVersion = "25.11";
}
