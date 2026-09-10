{ config, pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Optional, aber sinnvoll:
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virtiofsd
    OVMF
  ];

  # Für AMD:
  boot.kernelModules = [ "kvm-amd" ];

  # User darf VMs managen:
  users.users.bernd.extraGroups = [ "libvirtd" "kvm" ];
}
