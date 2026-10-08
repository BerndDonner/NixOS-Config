{ config, lib, pkgs, ... }:

{
  boot.initrd.luks.devices."vault" = {
    device = "/dev/disk/by-partlabel/NIXOS_VAULT";
    allowDiscards = true;
  };

  fileSystems."/secrets" = {
    device = "/dev/mapper/vault";
    fsType = "ext4";
    options = [ "noauto" "nofail" "x-systemd.automount" "x-systemd.idle-timeout=60" ];
  };
}

