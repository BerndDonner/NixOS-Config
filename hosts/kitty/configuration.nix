# Framework 16 (kitty) – host-specific configuration.
{ lib, pkgs, ... }:

{
  imports = [
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/initrd-ssh-unlock.nix
    ./hardware-configuration.nix
    ./vault.nix
    ./hibernate-hooks.nix
  ];

  # Separate EFI partition on the NixOS SSD.
  boot.supportedFilesystems.exfat = true;

  # Hibernate (swap partition).
  boot.resumeDevice = "/dev/disk/by-uuid/c4072834-5654-415d-a8af-95e8e160dc5b";
  boot.kernelParams = lib.mkAfter [
    "resume=/dev/disk/by-uuid/c4072834-5654-415d-a8af-95e8e160dc5b"
    "nvme_core.default_ps_max_latency_us=0"
  ];

  # Keep the kernel-managed shutdown/resume path on this AMD/UEFI laptop.
  systemd.sleep.settings.Sleep = {
    HibernateMode = "shutdown";
    HibernateDelaySec = "2min";
  };
  systemd.tmpfiles.rules = [
    "w /sys/power/disk - - - - shutdown"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "kitty";
  networking.networkmanager = {
    enable = true;
    settings.keyfile.path = "/secrets/nm";
  };
  systemd.services.NetworkManager.unitConfig.RequiresMountsFor = [
    "/secrets/nm"
  ];

  hardware.bluetooth.enable = true;
  users.users.bernd.extraGroups = [ "networkmanager" ];

  # Preserve the original host-specific compatibility baseline.
  system.stateVersion = "25.11";
}
