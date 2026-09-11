{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "cloud";
  networking.useDHCP = true;

  boot.loader.grub.enable = true;

  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.bleau = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    openssh.authorizedKeys.keyFiles = [
      ./bernds-desktop.pub
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.trusted-users = [
    "root"
    "bleau"
  ];

  environment.systemPackages = with pkgs; [
    # Basis
    git
    curl
    wget
    rsync

    # Archive / Kompression
    zip
    unzip
    zstd

    # CLI-Werkzeuge
    fd
    jq
    file
    bc

    # Server-Diagnose
    lsof
    strace
    tcpdump
    dnsutils
  ];

  system.stateVersion = "26.05";
}
