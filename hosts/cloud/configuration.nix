{ pkgs, ... }:

{
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
    git
    helix
    tmux
  ];

  system.stateVersion = "26.05";
}
