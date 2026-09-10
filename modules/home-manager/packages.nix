{ config, pkgs, lib, inputs, ... }:

{
  home.packages =
    (with pkgs; [
      firefox
      google-chrome
      discord
      magic-wormhole
      github-desktop
      qtcreator
      processing
      stm32cubemx
      kicad
      ngspice
      obs-studio
      xournalpp
      inkscape
      rustc
      haruna
      qbittorrent
      vlc
      gimp
      lua54Packages.luarocks
      ripgrep
      lazygit
      cargo
      opam
      gcc14
      tree
      gdu
      bottom
      nodejs
      wl-clipboard
      rclone
      krita
      xinput_calibrator
    ])
    ++ (with pkgs.kdePackages; [
      akonadi
      qtserialport
      pulseaudio-qt
      poppler
      plasma-thunderbolt
      plasma-browser-integration
      sddm-kcm
      kdeconnect-kde
      kubrick
      ksvg
      kate
      kwallet
      kwalletmanager
      wayland
    ])
    ++ [
      (pkgs.callPackage ../../pkgs/context/luametatex.nix {})
    ];
}
